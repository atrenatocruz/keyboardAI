import Foundation

public enum TargetMode: Equatable, Sendable {
    case selection, beforeCursor
}

public struct ImproveTarget: Equatable, Sendable {
    public let text: String
    public let mode: TargetMode

    public init(text: String, mode: TargetMode) {
        self.text = text
        self.mode = mode
    }
}

public enum TargetError: Error, Equatable {
    case empty, tooLong
}

public enum TextReplacer {
    public static let maxLength = 1000

    public static func target(selectedText: String?, contextBefore: String?) -> Result<ImproveTarget, TargetError> {
        let target: ImproveTarget
        if let selected = selectedText, !selected.isEmpty {
            target = ImproveTarget(text: selected, mode: .selection)
        } else {
            target = ImproveTarget(text: contextBefore ?? "", mode: .beforeCursor)
        }
        if target.text.allSatisfy(\.isWhitespace) { return .failure(.empty) }
        if target.text.count > maxLength { return .failure(.tooLong) }
        return .success(target)
    }

    public static func preservingWhitespace(of original: String, in improved: String) -> String {
        let leading = String(original.prefix(while: \.isWhitespace))
        let trailing = String(original.reversed().prefix(while: \.isWhitespace).reversed())
        let core = improved.trimmingCharacters(in: .whitespacesAndNewlines)
        return leading + core + trailing
    }

    public static func replaceActions(for target: ImproveTarget, with replacement: String) -> [TextAction] {
        switch target.mode {
        case .selection: return [.insert(replacement)]
        case .beforeCursor: return [.deleteBackward(target.text.count), .insert(replacement)]
        }
    }

    public static func undoActions(for target: ImproveTarget, replacement: String) -> [TextAction] {
        [.deleteBackward(replacement.count), .insert(target.text)]
    }

    public static func contextStillMatches(_ target: ImproveTarget, selectedText: String?, contextBefore: String?) -> Bool {
        switch target.mode {
        case .selection: return selectedText == target.text
        case .beforeCursor: return contextBefore?.hasSuffix(target.text) ?? false
        }
    }
}
