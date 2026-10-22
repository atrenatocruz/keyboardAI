import UIKit
import KeyboardCore

/// The system-style suggestion bar with the AI button on the left:
/// [ (✨) | suggestion | suggestion | suggestion ]
/// Tap ✨ to improve, hold it to pick the mood; after an improvement it turns into ↩︎ (undo) until the next key.
final class AIBarView: UIView {
    static let height: CGFloat = 44

    enum SuggestionTap {
        /// Keep the word as typed (the quoted slot).
        case keep(String)
        /// Replace the word being typed.
        case replace(String)
        /// Insert a predicted next word.
        case insert(String)
    }

    var onImprove: (() -> Void)?
    var onUndo: (() -> Void)?
    var onMoodTap: (() -> Void)?
    var onSuggestion: ((SuggestionTap) -> Void)?
    var mood: Mood = .natural { didSet { updateAccessibility() } }

    private let aiButton = AIOrbButton()
    private let spinner = UIActivityIndicatorView(style: .medium)
    private let messageLabel = UILabel()
    private var messageWork: DispatchWorkItem?

    private let suggestionStack = UIStackView()
    private let suggestionButtons = (0..<3).map { _ in UIButton(type: .system) }
    private let dividers = (0..<2).map { _ in UIView() }
    private let correctionHighlight = UIView()
    private var suggestions: Suggestions?

    private var isUndoAvailable = false
    private var isImproveEnabled = true
    private var isShowingMessage = false

    override init(frame: CGRect) {
        super.init(frame: frame)

        aiButton.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.isUndoAvailable ? self.onUndo?() : self.onImprove?()
        }, for: .touchUpInside)
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPress.minimumPressDuration = 0.4
        aiButton.addGestureRecognizer(longPress)

        spinner.color = .white
        spinner.hidesWhenStopped = true

        messageLabel.font = .systemFont(ofSize: 15, weight: .medium)
        messageLabel.textColor = .secondaryLabel
        messageLabel.textAlignment = .center
        messageLabel.adjustsFontSizeToFitWidth = true
        messageLabel.minimumScaleFactor = 0.8
        messageLabel.alpha = 0

        correctionHighlight.backgroundColor = UIColor.label.withAlphaComponent(0.1)
        correctionHighlight.layer.cornerRadius = 8
        correctionHighlight.layer.cornerCurve = .continuous
        correctionHighlight.isUserInteractionEnabled = false
        correctionHighlight.alpha = 0
        suggestionStack.addSubview(correctionHighlight)

        suggestionStack.distribution = .fillEqually
        for (index, button) in suggestionButtons.enumerated() {
            button.titleLabel?.font = .systemFont(ofSize: 17)
            button.titleLabel?.lineBreakMode = .byTruncatingMiddle
            button.tintColor = .label
            button.addAction(UIAction { [weak self] _ in self?.tapSuggestion(at: index) }, for: .touchUpInside)
            suggestionStack.addArrangedSubview(button)
        }
        for divider in dividers {
            divider.backgroundColor = .separator
            suggestionStack.addSubview(divider)
        }

        for v in [aiButton, suggestionStack, messageLabel] {
            v.translatesAutoresizingMaskIntoConstraints = false
            addSubview(v)
        }
        spinner.translatesAutoresizingMaskIntoConstraints = false
        aiButton.addSubview(spinner)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: Self.height),
            aiButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            aiButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            aiButton.widthAnchor.constraint(equalToConstant: 34),
            aiButton.heightAnchor.constraint(equalToConstant: 34),
            spinner.centerXAnchor.constraint(equalTo: aiButton.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: aiButton.centerYAnchor),
            suggestionStack.leadingAnchor.constraint(equalTo: aiButton.trailingAnchor, constant: 6),
            suggestionStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            suggestionStack.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            suggestionStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
            messageLabel.leadingAnchor.constraint(equalTo: suggestionStack.leadingAnchor, constant: 8),
            messageLabel.trailingAnchor.constraint(equalTo: suggestionStack.trailingAnchor, constant: -8),
            messageLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
        showSuggestions(nil)
        updateAccessibility()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    var improveAnchor: CGRect { aiButton.frame }

    override func layoutSubviews() {
        super.layoutSubviews()
        let slot = suggestionStack.bounds.width / 3
        let inset: CGFloat = 9
        for (i, divider) in dividers.enumerated() {
            divider.frame = CGRect(x: slot * CGFloat(i + 1), y: inset, width: 1 / max(traitCollection.displayScale, 1),
                                   height: suggestionStack.bounds.height - 2 * inset)
        }
        correctionHighlight.frame = CGRect(x: slot + 3, y: 0, width: slot - 6, height: suggestionStack.bounds.height)
    }

    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        if gesture.state == .began, !isUndoAvailable { onMoodTap?() }
    }

    // MARK: AI button states

    func setImproveEnabled(_ enabled: Bool) {
        isImproveEnabled = enabled
        aiButton.isEnabled = enabled || isUndoAvailable
    }

    func setLoading(_ loading: Bool) {
        messageWork?.cancel()
        aiButton.showsSymbol = !loading
        loading ? spinner.startAnimating() : spinner.stopAnimating()
        if loading { hideMessage() }
    }

    func showIdle() {
        messageWork?.cancel()
        isUndoAvailable = false
        aiButton.symbolName = "sparkles"
        aiButton.isEnabled = isImproveEnabled
        hideMessage()
        updateAccessibility()
    }

    func showUndo() {
        messageWork?.cancel()
        isUndoAvailable = true
        aiButton.symbolName = "arrow.uturn.backward"
        aiButton.isEnabled = true
        hideMessage()
        updateAccessibility()
    }

    /// Status text takes the suggestion slots for a moment, then the suggestions come back.
    func show(_ message: AIStatusMessage) {
        messageWork?.cancel()
        isShowingMessage = true
        messageLabel.text = message.text
        transition {
            self.messageLabel.alpha = 1
            self.suggestionStack.alpha = 0
        }
        let work = DispatchWorkItem { [weak self] in self?.hideMessage() }
        messageWork = work
        let delay: TimeInterval = message == .unchanged ? 1.5 : 2.5
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func hideMessage() {
        guard isShowingMessage else { return }
        isShowingMessage = false
        transition {
            self.messageLabel.alpha = 0
            self.suggestionStack.alpha = 1
        }
    }

    // MARK: Suggestions

    /// Typing a word: [“typed”] [correction or completion] [alternative]. Otherwise three predictions.
    func showSuggestions(_ suggestions: Suggestions?) {
        self.suggestions = suggestions
        var titles: [String] = []
        if let suggestions {
            if let typed = suggestions.typed, !suggestions.candidates.isEmpty { titles.append("“\(typed)”") }
            titles += suggestions.candidates
        }
        for (i, button) in suggestionButtons.enumerated() {
            let title = i < titles.count ? titles[i] : nil
            button.setTitle(title, for: .normal)
            button.isEnabled = title != nil
            button.accessibilityLabel = title
        }
        if let typed = suggestions?.typed, !titles.isEmpty { suggestionButtons[0].accessibilityLabel = "Manter \(typed)" }
        correctionHighlight.alpha = suggestions?.autocorrection != nil ? 1 : 0
        for (i, divider) in dividers.enumerated() {
            divider.isHidden = titles.count < i + 2 || suggestions?.autocorrection != nil
        }
    }

    private func tapSuggestion(at index: Int) {
        guard let suggestions else { return }
        if let typed = suggestions.typed {
            if index == 0 { onSuggestion?(.keep(typed)) }
            else if index - 1 < suggestions.candidates.count { onSuggestion?(.replace(suggestions.candidates[index - 1])) }
        } else if index < suggestions.candidates.count {
            onSuggestion?(.insert(suggestions.candidates[index]))
        }
    }

    private func updateAccessibility() {
        aiButton.accessibilityLabel = isUndoAvailable ? "Desfazer melhoria" : "Melhorar texto"
        aiButton.accessibilityHint = isUndoAvailable ? nil : "Tom: \(mood.displayName). Mantém premido para mudar."
    }

    /// Critically damped, interruptible (starts from the current presentation value).
    private func transition(_ changes: @escaping () -> Void) {
        let animator = UIViewPropertyAnimator(duration: 0.25, dampingRatio: 1, animations: changes)
        animator.isInterruptible = true
        animator.startAnimation()
    }
}

/// Round button with the app's indigo→purple gradient and a white SF Symbol.
private final class AIOrbButton: UIButton {
    private let gradient = CAGradientLayer()
    private let glyph = UIImageView()

    var symbolName = "sparkles" { didSet { updateGlyph() } }
    var showsSymbol = true { didSet { glyph.isHidden = !showsSymbol } }

    init() {
        super.init(frame: .zero)
        gradient.colors = [UIColor(red: 99 / 255, green: 102 / 255, blue: 241 / 255, alpha: 1).cgColor,
                           UIColor(red: 168 / 255, green: 85 / 255, blue: 247 / 255, alpha: 1).cgColor]
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = CGPoint(x: 1, y: 1)
        layer.addSublayer(gradient)
        glyph.tintColor = .white
        glyph.contentMode = .center
        glyph.isUserInteractionEnabled = false
        addSubview(glyph)
        updateGlyph()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradient.frame = bounds
        gradient.cornerRadius = bounds.height / 2
        glyph.frame = bounds
        bringSubviewToFront(glyph)
    }

    override var isHighlighted: Bool {
        didSet {
            UIViewPropertyAnimator(duration: 0.2, dampingRatio: 1) {
                self.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.9, y: 0.9) : .identity
            }.startAnimation()
        }
    }

    override var isEnabled: Bool { didSet { alpha = isEnabled ? 1 : 0.45 } }

    private func updateGlyph() {
        glyph.image = UIImage(systemName: symbolName,
                              withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold))
    }
}
