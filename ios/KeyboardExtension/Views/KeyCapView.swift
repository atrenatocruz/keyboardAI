import UIKit
import KeyboardCore

final class KeyCapView: UIView {
    let key: Key
    private let label = UILabel()
    private let icon = UIImageView()

    var isHighlighted = false { didSet { if oldValue != isHighlighted { updateColors() } } }
    var isSpecial: Bool {
        switch key {
        case .character, .space: return false
        default: return true
        }
    }

    /// iOS 26 system keys are noticeably rounder than earlier releases.
    static let cornerRadius: CGFloat = 8.5
    static let characterColor = UIColor { $0.userInterfaceStyle == .dark ? UIColor(white: 0.42, alpha: 1) : .white }
    static let specialColor = UIColor { $0.userInterfaceStyle == .dark ? UIColor(white: 0.27, alpha: 1) : UIColor(white: 0.68, alpha: 1) }

    init(key: Key) {
        self.key = key
        super.init(frame: .zero)
        layer.cornerRadius = Self.cornerRadius
        layer.cornerCurve = .continuous
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.3
        layer.shadowOffset = CGSize(width: 0, height: 1)
        layer.shadowRadius = 0
        isUserInteractionEnabled = false
        isAccessibilityElement = true
        accessibilityTraits = .keyboardKey

        label.textAlignment = .center
        label.textColor = .label
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.6
        icon.contentMode = .center
        icon.tintColor = .label
        addSubview(label)
        addSubview(icon)
        updateColors()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(title: String?, symbol: String?, fontSize: CGFloat, accessibility: String) {
        label.text = title
        label.font = .systemFont(ofSize: fontSize)
        icon.image = symbol.flatMap { UIImage(systemName: $0, withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .regular)) }
        accessibilityLabel = accessibility
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        label.frame = bounds.insetBy(dx: 2, dy: 0)
        icon.frame = bounds
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: Self.cornerRadius).cgPath
    }

    override func traitCollectionDidChange(_ previous: UITraitCollection?) {
        super.traitCollectionDidChange(previous)
        updateColors()
    }

    private func updateColors() {
        let normal = isSpecial ? Self.specialColor : Self.characterColor
        let pressed = isSpecial ? Self.characterColor : Self.specialColor
        backgroundColor = isHighlighted ? pressed : normal
        layer.borderWidth = UIAccessibility.isDarkerSystemColorsEnabled ? 1 : 0
        layer.borderColor = UIColor.separator.cgColor
    }
}
