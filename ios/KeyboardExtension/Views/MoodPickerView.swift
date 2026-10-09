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
            var config = UIButton.Configuration.plain()
            config.title = mood.displayName
            config.subtitle = mood.summary
            config.image = mood == selected ? UIImage(systemName: "checkmark") : nil
            config.imagePlacement = .trailing
            config.baseForegroundColor = .label
            config.titleAlignment = .leading
            config.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8)
            let button = UIButton(configuration: config)
            button.contentHorizontalAlignment = .fill
            button.accessibilityTraits = mood == selected ? [.button, .selected] : .button
            button.addAction(UIAction { [weak self] _ in
                self?.onSelect?(mood)
                self?.dismiss()
            }, for: .touchUpInside)
            stack.addArrangedSubview(button)
        }

        let width = min(bounds.width - 16, 300)
        let rowHeight: CGFloat = 52
        let height = min(CGFloat(Mood.allCases.count) * rowHeight, bounds.height - 8)
        panel.frame = CGRect(x: 8, y: 4, width: width, height: height)
        stack.frame = panel.bounds.insetBy(dx: 8, dy: 4)

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
