import UIKit
import KeyboardCore

final class AIBarView: UIView {
    static let height: CGFloat = 44

    var onImprove: (() -> Void)?
    var onUndo: (() -> Void)?
    var onMoodTap: (() -> Void)?
    var mood: Mood = .natural { didSet { moodButton.setTitle("\(mood.displayName) ▾", for: .normal) } }

    private let improveButton = UIButton(type: .system)
    private let moodButton = UIButton(type: .system)
    private let undoButton = UIButton(type: .system)
    private let spinner = UIActivityIndicatorView(style: .medium)
    private let messageLabel = UILabel()
    private var messageWork: DispatchWorkItem?

    override init(frame: CGRect) {
        super.init(frame: frame)

        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: "sparkles")
        config.title = "Melhorar"
        config.imagePadding = 6
        config.baseForegroundColor = .label
        improveButton.configuration = config
        improveButton.accessibilityLabel = "Melhorar texto"
        improveButton.addAction(UIAction { [weak self] _ in self?.onImprove?() }, for: .touchUpInside)
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPress.minimumPressDuration = 0.4
        improveButton.addGestureRecognizer(longPress)

        moodButton.titleLabel?.font = .systemFont(ofSize: 13)
        moodButton.tintColor = .secondaryLabel
        moodButton.accessibilityLabel = "Escolher mood"
        moodButton.addAction(UIAction { [weak self] _ in self?.onMoodTap?() }, for: .touchUpInside)

        var undoConfig = UIButton.Configuration.plain()
        undoConfig.image = UIImage(systemName: "arrow.uturn.backward")
        undoConfig.title = "Desfazer"
        undoConfig.imagePadding = 6
        undoConfig.baseForegroundColor = .label
        undoButton.configuration = undoConfig
        undoButton.accessibilityLabel = "Desfazer melhoria"
        undoButton.addAction(UIAction { [weak self] _ in self?.onUndo?() }, for: .touchUpInside)

        messageLabel.font = .systemFont(ofSize: 13, weight: .medium)
        messageLabel.textColor = .secondaryLabel
        messageLabel.textAlignment = .right
        messageLabel.adjustsFontSizeToFitWidth = true
        messageLabel.minimumScaleFactor = 0.8

        for v in [improveButton, moodButton, spinner, undoButton, messageLabel] {
            v.translatesAutoresizingMaskIntoConstraints = false
            addSubview(v)
        }
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: Self.height),
            improveButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            improveButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            spinner.centerXAnchor.constraint(equalTo: improveButton.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: centerYAnchor),
            moodButton.leadingAnchor.constraint(equalTo: improveButton.trailingAnchor, constant: 2),
            moodButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            undoButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            undoButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            messageLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            messageLabel.leadingAnchor.constraint(greaterThanOrEqualTo: moodButton.trailingAnchor, constant: 8),
            messageLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
        mood = .natural
        undoButton.alpha = 0
        messageLabel.alpha = 0
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    var improveAnchor: CGRect { improveButton.frame }

    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        if gesture.state == .began { onMoodTap?() }
    }

    func setImproveEnabled(_ enabled: Bool) {
        improveButton.isEnabled = enabled
    }

    func setLoading(_ loading: Bool) {
        messageWork?.cancel()
        improveButton.alpha = loading ? 0 : 1
        loading ? spinner.startAnimating() : spinner.stopAnimating()
        if loading { transition { self.undoButton.alpha = 0; self.messageLabel.alpha = 0 } }
    }

    func showIdle() {
        messageWork?.cancel()
        transition { self.undoButton.alpha = 0; self.messageLabel.alpha = 0 }
    }

    func showUndo() {
        messageWork?.cancel()
        transition { self.messageLabel.alpha = 0; self.undoButton.alpha = 1 }
    }

    func show(_ message: AIStatusMessage) {
        messageWork?.cancel()
        messageLabel.text = message.text
        transition { self.undoButton.alpha = 0; self.messageLabel.alpha = 1 }
        let work = DispatchWorkItem { [weak self] in self?.showIdle() }
        messageWork = work
        let delay: TimeInterval = message == .unchanged ? 1.5 : 2.5
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    /// Critically damped, interruptible (starts from the current presentation value).
    private func transition(_ changes: @escaping () -> Void) {
        let animator = UIViewPropertyAnimator(duration: 0.3, dampingRatio: 1, animations: changes)
        animator.isInterruptible = true
        animator.startAnimation()
    }
}
