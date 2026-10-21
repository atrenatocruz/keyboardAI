import UIKit
import KeyboardCore

final class AIBarView: UIView {
    static let height: CGFloat = 44

    var onImprove: (() -> Void)?
    var onUndo: (() -> Void)?
    var onMoodTap: (() -> Void)?
    /// (word, isTyped) — isTyped means "keep what I wrote".
    var onSuggestion: ((String, Bool) -> Void)?
    var mood: Mood = .natural { didSet { moodButton.setTitle("\(mood.displayName) ▾", for: .normal) } }

    private let improveButton = UIButton(type: .system)
    private let moodButton = UIButton(type: .system)
    private let undoButton = UIButton(type: .system)
    private let spinner = UIActivityIndicatorView(style: .medium)
    private let messageLabel = UILabel()
    private var messageWork: DispatchWorkItem?

    private let suggestionStack = UIStackView()
    private let suggestionButtons = (0..<3).map { _ in UIButton(type: .system) }
    private let dividers = (0..<2).map { _ in UIView() }
    private var suggestions: Suggestions?
    /// Undo, a status message or loading is on screen; suggestions wait until it clears.
    private var isShowingOverlay = false

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

        suggestionStack.distribution = .fillEqually
        for (index, button) in suggestionButtons.enumerated() {
            button.titleLabel?.font = .systemFont(ofSize: 16)
            button.titleLabel?.lineBreakMode = .byTruncatingMiddle
            button.tintColor = .label
            button.addAction(UIAction { [weak self] _ in self?.tapSuggestion(at: index) }, for: .touchUpInside)
            suggestionStack.addArrangedSubview(button)
        }
        for divider in dividers {
            divider.backgroundColor = .separator
            suggestionStack.addSubview(divider)
        }

        for v in [improveButton, moodButton, spinner, undoButton, messageLabel, suggestionStack] {
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
            suggestionStack.leadingAnchor.constraint(equalTo: improveButton.trailingAnchor),
            suggestionStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            suggestionStack.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            suggestionStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
        ])
        mood = .natural
        undoButton.alpha = 0
        messageLabel.alpha = 0
        updateMode(animated: false)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let slot = suggestionStack.bounds.width / 3
        let inset: CGFloat = 8
        for (i, divider) in dividers.enumerated() {
            divider.frame = CGRect(x: slot * CGFloat(i + 1), y: inset, width: 1 / max(traitCollection.displayScale, 1),
                                   height: suggestionStack.bounds.height - 2 * inset)
        }
    }

    // MARK: Suggestions

    /// nil → back to "✨ Melhorar · mood ▾".
    func showSuggestions(_ suggestions: Suggestions?) {
        let visible = suggestions.map { !$0.candidates.isEmpty } ?? false
        self.suggestions = visible ? suggestions : nil
        if let suggestions, visible {
            let titles = ["“\(suggestions.typed)”"] + suggestions.candidates
            for (i, button) in suggestionButtons.enumerated() {
                let title = i < titles.count ? titles[i] : nil
                button.setTitle(title, for: .normal)
                button.isEnabled = title != nil
                let bold = i == 1 && suggestions.autocorrection != nil
                button.titleLabel?.font = .systemFont(ofSize: 16, weight: bold ? .semibold : .regular)
                button.accessibilityLabel = i == 0 ? "Manter \(suggestions.typed)" : title
            }
        }
        updateMode(animated: true)
    }

    private func tapSuggestion(at index: Int) {
        guard let suggestions else { return }
        if index == 0 {
            onSuggestion?(suggestions.typed, true)
        } else if index - 1 < suggestions.candidates.count {
            onSuggestion?(suggestions.candidates[index - 1], false)
        }
    }

    /// Suggestions replace the mood button and shrink ✨ to an icon, like the system predictive bar.
    private func updateMode(animated: Bool) {
        let showing = suggestions != nil && !isShowingOverlay
        improveButton.configuration?.title = showing ? nil : "Melhorar"
        let changes = {
            self.suggestionStack.alpha = showing ? 1 : 0
            self.moodButton.alpha = showing ? 0 : 1
        }
        suggestionStack.isUserInteractionEnabled = showing
        moodButton.isUserInteractionEnabled = !showing
        animated ? transition(changes) : changes()
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
        if loading {
            isShowingOverlay = true
            updateMode(animated: true)
            transition { self.undoButton.alpha = 0; self.messageLabel.alpha = 0 }
        }
    }

    func showIdle() {
        messageWork?.cancel()
        isShowingOverlay = false
        updateMode(animated: true)
        transition { self.undoButton.alpha = 0; self.messageLabel.alpha = 0 }
    }

    func showUndo() {
        messageWork?.cancel()
        isShowingOverlay = true
        updateMode(animated: true)
        transition { self.messageLabel.alpha = 0; self.undoButton.alpha = 1 }
    }

    func show(_ message: AIStatusMessage) {
        messageWork?.cancel()
        isShowingOverlay = true
        updateMode(animated: true)
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
