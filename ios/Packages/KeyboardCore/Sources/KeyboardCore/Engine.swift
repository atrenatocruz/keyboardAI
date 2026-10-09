public enum ShiftState: Equatable, Sendable {
    case off, on, capsLock
}

public struct KeyboardState: Equatable, Sendable {
    public var page: KeyboardPage
    public var shift: ShiftState

    public init(page: KeyboardPage = .letters, shift: ShiftState = .on) {
        self.page = page
        self.shift = shift
    }
}

public enum KeyEvent: Equatable, Sendable {
    case character(String)
    case space
    case delete
    case returnKey
    case shift(doubleTap: Bool)
    case switchPage(KeyboardPage)
}

public struct KeyboardEngine: Sendable {
    public private(set) var state: KeyboardState
    public var autoCapitalizationEnabled: Bool

    public init(autoCapitalizationEnabled: Bool = true) {
        self.autoCapitalizationEnabled = autoCapitalizationEnabled
        self.state = KeyboardState(page: .letters, shift: autoCapitalizationEnabled ? .on : .off)
    }

    public func displayText(for character: String) -> String {
        state.shift == .off ? character : character.uppercased()
    }

    public mutating func handle(_ event: KeyEvent, contextBefore: String?) -> [TextAction] {
        let context = contextBefore ?? ""
        let actions: [TextAction]

        switch event {
        case .character(let character):
            actions = [.insert(displayText(for: character))]
        case .space:
            actions = Self.shouldInsertPeriod(context) ? [.deleteBackward(1), .insert(". ")] : [.insert(" ")]
            state.page = .letters
        case .delete:
            actions = [.deleteBackward(1)]
        case .returnKey:
            actions = [.insert("\n")]
        case .shift(let doubleTap):
            switch state.shift {
            case .off: state.shift = doubleTap ? .capsLock : .on
            case .on: state.shift = doubleTap ? .capsLock : .off
            case .capsLock: state.shift = .off
            }
            return []
        case .switchPage(let page):
            state.page = page
            return []
        }

        updateAutoCapitalization(contextBefore: TextAction.apply(actions, to: context))
        return actions
    }

    public mutating func updateAutoCapitalization(contextBefore: String?) {
        guard state.shift != .capsLock else { return }
        state.shift = autoCapitalizationEnabled && Self.shouldCapitalize(contextBefore ?? "") ? .on : .off
    }

    public static func shouldCapitalize(_ context: String) -> Bool {
        guard let last = context.last else { return true }
        if last == "\n" { return true }
        guard last == " " else { return false }
        guard let lastNonSpace = context.last(where: { $0 != " " }) else { return true }
        return "\n.!?…".contains(lastNonSpace)
    }

    static func shouldInsertPeriod(_ context: String) -> Bool {
        guard context.hasSuffix(" "), !context.hasSuffix("  ") else { return false }
        guard let beforeSpace = context.dropLast().last else { return false }
        return beforeSpace.isLetter || beforeSpace.isNumber
    }
}
