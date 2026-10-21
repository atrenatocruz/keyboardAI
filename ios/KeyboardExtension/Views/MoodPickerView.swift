import UIKit
import KeyboardCore

/// Mood list that grows out of the ✨ button and returns to it (spatial consistency, §7).
final class MoodPickerView: UIView {
    var onSelect: ((Mood) -> Void)?
    var onDismiss: (() -> Void)?

    private let backdrop = UIButton(type: .custom)
    private let panel = UIVisualEffectView(effect: UIBlurEffect(style: .systemThickMaterial))
    private let stack = UIStackView()
    private var anchor: CGRect = .zero
    private var isDismissing = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        backdrop.addAction(UIAction { [weak self] _ in self?.dismiss() }, for: .touchUpInside)
        addSubview(backdrop)
        panel.layer.cornerRadius = 14
        panel.layer.cornerCurve = .continuous
        panel.clipsToBounds = true
        stack.axis = .vertical
        stack.distribution = .fillEqually
        panel.contentView.addSubview(stack)
        addSubview(panel)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func present(from anchor: CGRect, in container: UIView, selected: Mood) {
        self.anchor = anchor
        isDismissing = false
        isUserInteractionEnabled = true
        frame = container.bounds
        container.addSubview(self)
        backdrop.frame = bounds

        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for mood in Mood.allCases {
            let row = MoodRow(mood: mood, isSelected: mood == selected)
            row.addAction(UIAction { [weak self] _ in
                self?.onSelect?(mood)
                self?.dismiss()
            }, for: .touchUpInside)
            stack.addArrangedSubview(row)
        }

        // Covers the whole keyboard so no keys peek out from behind the list.
        panel.frame = bounds.insetBy(dx: 6, dy: 4)
        stack.frame = panel.bounds.insetBy(dx: 0, dy: 4)

        if UIAccessibility.isReduceMotionEnabled {
            panel.alpha = 0
            UIView.animate(withDuration: 0.2) { self.panel.alpha = 1 }
        } else {
            panel.transform = collapsedTransform()
            panel.alpha = 0
            let animator = UIViewPropertyAnimator(duration: 0.3, dampingRatio: 1) {
                self.panel.transform = .identity
                self.panel.alpha = 1
            }
            animator.startAnimation()
        }
    }

    func dismiss() {
        guard !isDismissing else { return }
        isDismissing = true
        isUserInteractionEnabled = false
        let finish = { [weak self] in
            self?.removeFromSuperview()
            self?.onDismiss?()
        }
        if UIAccessibility.isReduceMotionEnabled {
            UIView.animate(withDuration: 0.2, animations: { self.panel.alpha = 0 }, completion: { _ in finish() })
        } else {
            let animator = UIViewPropertyAnimator(duration: 0.3, dampingRatio: 1) {
                self.panel.transform = self.collapsedTransform()
                self.panel.alpha = 0
            }
            animator.addCompletion { _ in finish() }
            animator.startAnimation()
        }
    }

    /// Scales the panel down onto the anchor (the ✨ button) so it enters and exits along the same path.
    private func collapsedTransform() -> CGAffineTransform {
        let scale: CGFloat = 0.2
        let dx = anchor.midX - panel.center.x
        let dy = anchor.midY - panel.center.y
        return CGAffineTransform(translationX: dx, y: dy).scaledBy(x: scale, y: scale)
    }
}

/// One mood: title and summary left-aligned, checkmark pinned to the trailing edge.
private final class MoodRow: UIControl {
    private let titleLabel = UILabel()
    private let summaryLabel = UILabel()
    private let check = UIImageView(image: UIImage(systemName: "checkmark"))

    init(mood: Mood, isSelected: Bool) {
        super.init(frame: .zero)
        titleLabel.text = mood.displayName
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = .label
        summaryLabel.text = mood.summary
        summaryLabel.font = .systemFont(ofSize: 13)
        summaryLabel.textColor = .secondaryLabel
        summaryLabel.adjustsFontSizeToFitWidth = true
        summaryLabel.minimumScaleFactor = 0.85
        check.tintColor = .tintColor
        check.isHidden = !isSelected
        check.setContentHuggingPriority(.required, for: .horizontal)

        let labels = UIStackView(arrangedSubviews: [titleLabel, summaryLabel])
        labels.axis = .vertical
        labels.spacing = 1
        let row = UIStackView(arrangedSubviews: [labels, check])
        row.alignment = .center
        row.spacing = 12
        row.isUserInteractionEnabled = false
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            row.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        isAccessibilityElement = true
        accessibilityLabel = "\(mood.displayName), \(mood.summary)"
        accessibilityTraits = isSelected ? [.button, .selected] : .button
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var isHighlighted: Bool {
        didSet { backgroundColor = isHighlighted ? UIColor.label.withAlphaComponent(0.08) : .clear }
    }
}
