import UIKit
import KeyboardCore

struct ImproveState {
    var isImproving = false
    var lastImprove: (target: ImproveTarget, replacement: String)?
}

extension KeyboardViewController {
    private var client: ImproveClient? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "KeyboardAIBaseURL") as? String,
              let url = URL(string: raw), url.scheme == "https" || url.scheme == "http" else { return nil }
        return ImproveClient(baseURL: url, installID: settings.installID)
    }

    func setUpAI() {
        aiBar.mood = settings.mood
        aiBar.onImprove = { [weak self] in self?.improve() }
        aiBar.onUndo = { [weak self] in self?.undoImprove() }
        aiBar.onMoodTap = { [weak self] in self?.presentMoodPicker() }
    }

    func refreshImproveAvailability() {
        guard !improveState.isImproving else { return }
        let proxy = textDocumentProxy
        let result = TextReplacer.target(selectedText: proxy.selectedText, contextBefore: proxy.documentContextBeforeInput)
        if case .failure(.empty) = result { aiBar.setImproveEnabled(false) } else { aiBar.setImproveEnabled(true) }
    }

    func presentMoodPicker() {
        guard !improveState.isImproving else { return }
        let picker = MoodPickerView()
        picker.onSelect = { [weak self] mood in
            self?.settings.mood = mood
            self?.aiBar.mood = mood
        }
        let anchor = aiBar.convert(aiBar.improveAnchor, to: view)
        picker.present(from: anchor, in: view, selected: settings.mood)
    }

    func improve() {
        guard !improveState.isImproving else { return }
        guard hasFullAccess else {
            aiBar.show(.noFullAccess)
            return
        }
        let proxy = textDocumentProxy
        let target: ImproveTarget
        switch TextReplacer.target(selectedText: proxy.selectedText, contextBefore: proxy.documentContextBeforeInput) {
        case .failure(.empty): return
        case .failure(.tooLong):
            aiBar.show(.tooLong)
            haptics.error()
            return
        case .success(let t): target = t
        }
        guard let client else {
            aiBar.show(.server)
            return
        }

        improveState.isImproving = true
        improveState.lastImprove = nil
        aiBar.setLoading(true)
        keyboardView.isLocked = true
        let mood = settings.mood

        Task { @MainActor [weak self] in
            do {
                let result = try await client.improve(text: target.text, mood: mood)
                self?.finishImprove(target: target, improved: result.text)
            } catch let error as ImproveError {
                self?.failImprove(AIStatusMessage(error))
            } catch {
                self?.failImprove(.server)
            }
        }
    }

    private func endLoading() {
        improveState.isImproving = false
        aiBar.setLoading(false)
        keyboardView.isLocked = false
    }

    private func finishImprove(target: ImproveTarget, improved: String) {
        endLoading()
        let proxy = textDocumentProxy
        guard TextReplacer.contextStillMatches(target, selectedText: proxy.selectedText,
                                               contextBefore: proxy.documentContextBeforeInput) else {
            aiBar.show(.contextChanged)
            return
        }
        let replacement = TextReplacer.preservingWhitespace(of: target.text, in: improved)
        guard replacement != target.text else {
            aiBar.show(.unchanged)
            return
        }
        apply(TextReplacer.replaceActions(for: target, with: replacement))
        improveState.lastImprove = (target, replacement)
        aiBar.showUndo()
        haptics.success()
        lastSyncedContext = nil   // re-evaluate auto-caps after the replacement
        syncWithDocument()
    }

    private func failImprove(_ message: AIStatusMessage) {
        endLoading()
        aiBar.show(message)
        haptics.error()
    }

    func undoImprove() {
        guard let last = improveState.lastImprove else { return }
        apply(TextReplacer.undoActions(for: last.target, replacement: last.replacement))
        improveState.lastImprove = nil
        aiBar.showIdle()
        lastSyncedContext = nil   // re-evaluate auto-caps after the undo
        syncWithDocument()
    }
}
