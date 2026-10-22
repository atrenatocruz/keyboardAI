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
    let spellChecker = SystemSpellChecker()
    var autocorrectState = AutocorrectState()
    /// Loaded off the main thread at launch; suggestions fall back to the plain spell checker until then.
    var wordFrequency: WordFrequency?

    override func loadView() {
        let input = UIInputView(frame: .zero, inputViewStyle: .keyboard)
        input.allowsSelfSizing = true
        inputView = input
        view = input
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
        setUpAutocorrect()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        haptics.isEnabled = hasFullAccess && settings.hapticsEnabled
        haptics.prepare()
        lastSyncedContext = nil
        keyboardView.resetPanels()
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
        refreshSuggestions()
        refreshReturnKey()
    }

    /// Like the system keyboard, ⏎ is disabled on an empty field when the app asks for it (e.g. a send box).
    func refreshReturnKey() {
        let proxy = textDocumentProxy
        keyboardView.isReturnEnabled = proxy.enablesReturnKeyAutomatically != true || proxy.hasText
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
        let pendingUndo = autocorrectState.lastCorrection
        autocorrectState.lastCorrection = nil
        switch input {
        case .key(.character(let c)):
            autocorrectBefore(separator: c)
            perform(.character(c))
        case .key(.space):
            autocorrectBefore(separator: " ")
            perform(.space)
        case .key(.delete):
            if !undoAutocorrect(pendingUndo) { perform(.delete) }
        case .key(.returnKey):
            autocorrectBefore(separator: "\n")
            perform(.returnKey)
        case .key(.page(let page)): perform(.switchPage(page))
        case .key(.nextKeyboard): advanceToNextInputMode()
        case .key(.shift), .key(.emoji): break   // handled inside KeyboardView
        case .text(let text):
            apply([.insert(text)])
            lastSyncedContext = nil
            syncWithDocument()
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
        // textDidChange isn't called for our own insertions, so re-check here
        refreshImproveAvailability()
        refreshSuggestions()
        refreshReturnKey()
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
