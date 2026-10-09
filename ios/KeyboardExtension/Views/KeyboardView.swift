import UIKit
import KeyboardCore

final class KeyboardView: UIView, UIInputViewAudioFeedback {
    enum Input {
        case key(Key)
        case shiftTap(doubleTap: Bool)
        case accent(String)
    }

    static let preferredHeight: CGFloat = 216

    var onInput: ((Input) -> Void)?
    var onKeyDown: (() -> Void)?
    var state = KeyboardState() { didSet { if state != oldValue { rebuild() } } }
    var showsNextKeyboard = true { didSet { if showsNextKeyboard != oldValue { rebuild() } } }
    var returnTitle = "intro" { didSet { if returnTitle != oldValue { rebuild() } } }
    var isLocked = false { didSet { alpha = isLocked ? 0.5 : 1 } }

    var enableInputClicksWhenVisible: Bool { true }

    private var keyViews: [KeyCapView] = []
    private var active: [ObjectIdentifier: KeyCapView] = [:]
    private let popup = KeyPopupView()
    private let accentPicker = AccentPickerView()
    private var longPressTimer: Timer?
    private var repeatTimer: Timer?
    private var repeatCount = 0
    private var lastShiftTap: Date?

    private let sideMargin: CGFloat = 3
    private let keyGap: CGFloat = 6
    private let rowGap: CGFloat = 11
    private let topPadding: CGFloat = 8
    private let bottomPadding: CGFloat = 4

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        clipsToBounds = false
        addSubview(popup)
        addSubview(accentPicker)
        rebuild()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: Building

    private var builtKeys: [Key] = []

    /// Same keys (e.g. only shift changed) → just relabel, keeping views, frames and active touches.
    /// Different keys (page or globe changed) → recreate and lay out immediately so hit-testing never sees zero frames.
    private func rebuild() {
        let keys = KeyboardLayout.rows(for: state.page, includeNextKeyboard: showsNextKeyboard).flatMap { $0 }
        if keys == builtKeys {
            keyViews.forEach(configure)
            return
        }
        keyViews.forEach { $0.removeFromSuperview() }
        // Release held keys first so timers, popup, picker and highlights don't outlive their views.
        active.values.forEach(release)
        active.removeAll()
        builtKeys = keys
        keyViews = keys.map { key in
            let v = KeyCapView(key: key)
            configure(v)
            insertSubview(v, belowSubview: popup)
            return v
        }
        setNeedsLayout()
        layoutIfNeeded()
    }

    private func configure(_ v: KeyCapView) {
        switch v.key {
        case .character(let c):
            let text = state.page == .letters && state.shift != .off ? c.uppercased() : c
            v.configure(title: text, symbol: nil, fontSize: 23, accessibility: text)
        case .shift:
            let symbol = state.shift == .capsLock ? "capslock.fill" : (state.shift == .on ? "shift.fill" : "shift")
            v.configure(title: nil, symbol: symbol, fontSize: 16, accessibility: "Maiúsculas")
        case .delete:
            v.configure(title: nil, symbol: "delete.left", fontSize: 16, accessibility: "Apagar")
        case .space:
            v.configure(title: "espaço", symbol: nil, fontSize: 16, accessibility: "Espaço")
        case .returnKey:
            v.configure(title: returnTitle, symbol: nil, fontSize: 16, accessibility: returnTitle)
        case .nextKeyboard:
            v.configure(title: nil, symbol: "globe", fontSize: 16, accessibility: "Teclado seguinte")
        case .page(let page):
            let title = page == .letters ? "ABC" : (page == .numbers ? "123" : "#+=")
            v.configure(title: title, symbol: nil, fontSize: 16, accessibility: title)
        }
    }

    // MARK: Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        let rows = KeyboardLayout.rows(for: state.page, includeNextKeyboard: showsNextKeyboard)
        let width = bounds.width - 2 * sideMargin
        let unit = (width - 9 * keyGap) / 10
        let rowHeight = (bounds.height - topPadding - bottomPadding - 3 * rowGap) / 4
        var index = 0
        for (r, row) in rows.enumerated() {
            let y = topPadding + CGFloat(r) * (rowHeight + rowGap)
            let frames = rowFrames(row, rowIndex: r, unit: unit, width: width, y: y, height: rowHeight)
            for frame in frames {
                keyViews[index].frame = frame
                index += 1
            }
        }
    }

    private func rowFrames(_ row: [Key], rowIndex: Int, unit: CGFloat, width: CGFloat, y: CGFloat, height: CGFloat) -> [CGRect] {
        let x0 = sideMargin
        let isCharacter: (Key) -> Bool = { if case .character = $0 { return true } else { return false } }

        if row.allSatisfy(isCharacter) {
            let w = (width - CGFloat(row.count - 1) * keyGap) / CGFloat(row.count)
            return row.enumerated().map { CGRect(x: x0 + CGFloat($0.offset) * (w + keyGap), y: y, width: w, height: height) }
        }

        if rowIndex == 3 {
            // Bottom row: fixed-width side keys, space takes the rest.
            let fixed: (Key) -> CGFloat = { key in
                switch key {
                case .returnKey: return unit * 2.2
                case .space: return 0
                default: return unit * 1.3
                }
            }
            let fixedTotal = row.map(fixed).reduce(0, +)
            let spaceWidth = width - fixedTotal - CGFloat(row.count - 1) * keyGap
            var x = x0
            return row.map { key in
                let w = key == .space ? spaceWidth : fixed(key)
                defer { x += w + keyGap }
                return CGRect(x: x, y: y, width: w, height: height)
            }
        }

        // Row with a special key on each side and characters in the middle.
        let side = unit * 1.3
        let middle = Array(row.dropFirst().dropLast())
        let available = width - 2 * side - 2 * keyGap
        let w = min(unit * 1.45, (available - CGFloat(middle.count - 1) * keyGap) / CGFloat(middle.count))
        let used = CGFloat(middle.count) * w + CGFloat(middle.count - 1) * keyGap
        var x = x0 + side + keyGap + (available - used) / 2
        var frames = [CGRect(x: x0, y: y, width: side, height: height)]
        for _ in middle {
            frames.append(CGRect(x: x, y: y, width: w, height: height))
            x += w + keyGap
        }
        frames.append(CGRect(x: x0 + width - side, y: y, width: side, height: height))
        return frames
    }

    // MARK: Touches

    private func nearestKey(to point: CGPoint) -> KeyCapView? {
        keyViews.min { distance($0.frame, point) < distance($1.frame, point) }
    }

    private func distance(_ rect: CGRect, _ p: CGPoint) -> CGFloat {
        let dx = max(rect.minX - p.x, 0, p.x - rect.maxX)
        let dy = max(rect.minY - p.y, 0, p.y - rect.maxY)
        return dx * dx + dy * dy
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !isLocked else { return }
        for touch in touches {
            // Rollover: a new touch commits any key still held.
            for (id, held) in active where id != ObjectIdentifier(touch) {
                if accentPicker.isHidden { commit(held) }
                release(held)
                active[id] = nil
            }
            guard let keyView = nearestKey(to: touch.location(in: self)) else { continue }
            active[ObjectIdentifier(touch)] = keyView
            press(keyView)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            guard let current = active[ObjectIdentifier(touch)] else { continue }
            let point = touch.location(in: self)
            if !accentPicker.isHidden {
                accentPicker.updateSelection(forX: point.x)
                continue
            }
            guard case .character = current.key,
                  let target = nearestKey(to: point), target !== current,
                  case .character = target.key else { continue }
            release(current)
            active[ObjectIdentifier(touch)] = target
            press(target, silent: true)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            guard let keyView = active.removeValue(forKey: ObjectIdentifier(touch)) else { continue }
            if !accentPicker.isHidden {
                if let accent = accentPicker.selected { onInput?(.accent(accent)) }
            } else {
                commit(keyView)
            }
            release(keyView)
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            if let keyView = active.removeValue(forKey: ObjectIdentifier(touch)) { release(keyView) }
        }
    }

    // MARK: Press / release / commit

    private func press(_ keyView: KeyCapView, silent: Bool = false) {
        keyView.isHighlighted = true
        if !silent {
            onKeyDown?()
            UIDevice.current.playInputClick()
        }
        switch keyView.key {
        case .character(let c):
            let shown = state.page == .letters && state.shift != .off ? c.uppercased() : c
            popup.show(text: shown, above: keyView.frame, in: bounds)
            let variants = Accents.variants(for: c, uppercase: state.shift != .off)
            longPressTimer?.invalidate()
            if !variants.isEmpty && state.page == .letters {
                longPressTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: false) { [weak self] _ in
                    guard let self else { return }
                    self.popup.hide()
                    self.accentPicker.show(options: variants, above: keyView.frame, in: self.bounds)
                }
            }
        case .delete:
            onInput?(.key(.delete))
            startRepeat()
        case .shift:
            let now = Date()
            let isDouble = lastShiftTap.map { now.timeIntervalSince($0) < 0.3 } ?? false
            lastShiftTap = isDouble ? nil : now
            onInput?(.shiftTap(doubleTap: isDouble))
        default:
            break
        }
    }

    private func commit(_ keyView: KeyCapView) {
        switch keyView.key {
        case .delete, .shift: break   // already handled on touch-down
        default: onInput?(.key(keyView.key))
        }
    }

    private func release(_ keyView: KeyCapView) {
        keyView.isHighlighted = false
        longPressTimer?.invalidate()
        longPressTimer = nil
        repeatTimer?.invalidate()
        repeatTimer = nil
        popup.hide()
        accentPicker.hide()
    }

    private func startRepeat() {
        repeatCount = 0
        repeatTimer?.invalidate()
        repeatTimer = Timer.scheduledTimer(withTimeInterval: 0.45, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.onInput?(.key(.delete))
            self.repeatCount += 1
            self.scheduleRepeat(interval: 0.1)
        }
    }

    private func scheduleRepeat(interval: TimeInterval) {
        repeatTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] timer in
            guard let self else { return }
            self.onInput?(.key(.delete))
            self.repeatCount += 1
            if self.repeatCount == 10 && interval > 0.05 {
                timer.invalidate()
                self.scheduleRepeat(interval: 0.05)
            }
        }
    }
}
