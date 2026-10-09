public enum TextAction: Equatable, Sendable {
    case insert(String)
    /// Number of user-perceived characters (Swift `Character`s) to delete before the cursor.
    case deleteBackward(Int)

    public static func apply(_ actions: [TextAction], to context: String) -> String {
        var result = context
        for action in actions {
            switch action {
            case .insert(let text): result += text
            case .deleteBackward(let count): result = String(result.dropLast(count))
            }
        }
        return result
    }
}
