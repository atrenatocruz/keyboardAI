import UIKit
import KeyboardCore

final class KeyboardViewController: UIInputViewController {
    private var engine = KeyboardEngine()
    let settings = SettingsStore()
    let haptics = Haptics()
    let keyboardView = KeyboardView()
    let contentStack = UIStackView()
    let aiBar = AIBarView()
    var improveState = ImproveState()
    var lastSyncedContext: String?

    override func loadView() {
        let input = UIInputView(frame: .zero, inputViewStyle: .keyboard)
        input.allowsSelfSizing = true
        inputView = input
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        contentStack.axis = .vertical
        contentStack.addArrangedSubview(aiBar)
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.addArrangedSubview(keyboardView)
        view.addSubview(contentStack)

        let height = keyboardView.heightAnchor.constraint(equalToConstant: KeyboardView.preferredHeight)
        height.priority = UILayoutPriority(999)
        NSLayoutConstraint.activate([
            contentStack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            contentStack.topAnchor.constraint(equalTo: view.topAnchor),
            contentStack.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            height,
        ])

        keyboardView.onKeyDown = { [weak self] in self?.haptics.keyTap() }
        keyboardView.onInput = { [weak self] input in self?.handle(input) }
        setUpAI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        haptics.isEnabled = hasFullAccess && settings.hapticsEnabled
        haptics.prepare()
        lastSyncedContext = nil
        syncWithDocument()
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        keyboardView.showsNextKeyboard = needsInputModeSwitchKey
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        syncWithDocument()
    }

    func syncWithDocument() {
        let proxy = textDocumentProxy
        engine.autoCapitalizationEnabled = (proxy.autocapitalizationType ?? .sentences) != .none
        let context = proxy.documentContextBeforeInput
        if context != lastSyncedContext {
            engine.updateAutoCapitalization(contextBefore: context)
            lastSyncedContext = context
        }
        keyboardView.returnTitle = returnKeyTitle(for: proxy.returnKeyType)
        keyboardView.state = engine.state
        if let last = improveState.lastImprove,
           textDocumentProxy.documentContextBeforeInput?.hasSuffix(last.replacement) != true {
            improveState.lastImprove = nil
            aiBar.showIdle()
        }
        refreshImproveAvailability()
    }

    /// Any key press clears the pending undo (spec §4).
    func willHandleKeyInput() {
        if improveState.lastImprove != nil {
            improveState.lastImprove = nil
            aiBar.showIdle()
        }
    }

    private func handle(_ input: KeyboardView.Input) {
        guard !improveState.isImproving else { return }
        willHandleKeyInput()
        switch input {
        case .key(.character(let c)): perform(.character(c))
        case .key(.space): perform(.space)
        case .key(.delete): perform(.delete)
        case .key(.returnKey): perform(.returnKey)
        case .key(.page(let page)): perform(.switchPage(page))
        case .key(.nextKeyboard): advanceToNextInputMode()
        case .key(.shift): break
        case .shiftTap(let doubleTap): perform(.shift(doubleTap: doubleTap))
        case .accent(let accent):
            apply([.insert(accent)])
            lastSyncedContext = nil   // force re-evaluation of auto-caps after the accent
            syncWithDocument()
        }
    }

    func perform(_ event: KeyEvent) {
        apply(engine.handle(event, contextBefore: textDocumentProxy.documentContextBeforeInput))
        keyboardView.state = engine.state
        lastSyncedContext = textDocumentProxy.documentContextBeforeInput
    }

    func apply(_ actions: [TextAction]) {
        for action in actions {
            switch action {
            case .insert(let text): textDocumentProxy.insertText(text)
            case .deleteBackward(let count): for _ in 0..<count { textDocumentProxy.deleteBackward() }
            }
        }
    }
}
