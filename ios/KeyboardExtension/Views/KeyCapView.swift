import UIKit
import KeyboardCore

/// One key, styled after the iOS 26 system keyboard: very rounded, flat, and in dark mode every key shares one gray.
final class KeyCapView: UIView {
    let key: Key
    private let label = UILabel()
    private let icon = UIImageView()

    var isHighlighted = false { didSet { if oldValue != isHighlighted { updateColors() } } }
    /// Shift while engaged: white key with a dark glyph, like the system keyboard.
    var isActive = false { didSet { if oldValue != isActive { updateColors() } } }
    /// Return key when the field is empty and the app asked for it to enable automatically.
    var isDimmed = false { didSet { if oldValue != isDimmed { updateColors() } } }

    var isSpecial: Bool {
        switch key {
        case .character, .space: return false
        default: return true
        }
    }

    static let cornerRadius: CGFloat = 8.5
    static let characterColor = UIColor { $0.userInterfaceStyle == .dark ? UIColor(white: 0.40, alpha: 1) : .white }
    static let specialColor = UIColor { $0.userInterfaceStyle == .dark ? UIColor(white: 0.40, alpha: 1) : UIColor(white: 0.70, alpha: 1) }
    static let pressedColor = UIColor { $0.userInterfaceStyle == .dark ? UIColor(white: 0.56, alpha: 1) : UIColor(white: 0.82, alpha: 1) }

    init(key: Key) {
        self.key = key
        super.init(frame: .zero)
        layer.cornerRadius = Self.cornerRadius
        layer.cornerCurve = .continuous
        isUserInteractionEnabled = false
        isAccessibilityElement = true
        accessibilityTraits = .keyboardKey

        label.textAlignment = .center
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.6
        icon.contentMode = .center
        addSubview(label)
        addSubview(icon)
        updateColors()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(title: String?, symbol: String?, fontSize: CGFloat, accessibility: String) {
        label.text = title
        label.font = .systemFont(ofSize: fontSize)
        icon.image = symbol.flatMap { UIImage(systemName: $0, withConfiguration: UIImage.SymbolConfiguration(pointSize: 19, weight: .regular)) }
        accessibilityLabel = accessibility
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        label.frame = bounds.insetBy(dx: 2, dy: 0)
        icon.frame = bounds
    }

    override func traitCollectionDidChange(_ previous: UITraitCollection?) {
        super.traitCollectionDidChange(previous)
        updateColors()
    }

    private func updateColors() {
        let normal = isSpecial ? Self.specialColor : Self.characterColor
        backgroundColor = isActive ? .white : (isHighlighted ? Self.pressedColor : normal)
        let foreground: UIColor = isActive ? .black : .label
        label.textColor = foreground
        icon.tintColor = foreground
        label.alpha = isDimmed ? 0.35 : 1
        icon.alpha = isDimmed ? 0.35 : 1
        layer.borderWidth = UIAccessibility.isDarkerSystemColorsEnabled ? 1 : 0
        layer.borderColor = UIColor.separator.cgColor
    }
}
