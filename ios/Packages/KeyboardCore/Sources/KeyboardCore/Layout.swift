public enum KeyboardPage: Hashable, Sendable {
    case letters, numbers, symbols
}

public enum Key: Hashable, Sendable {
    case character(String)
    case shift
    case delete
    case space
    case returnKey
    case nextKeyboard
    case page(KeyboardPage)
}

public enum KeyboardLayout {
    public static func rows(for page: KeyboardPage, includeNextKeyboard: Bool) -> [[Key]] {
        let c: (String) -> [Key] = { $0.split(separator: " ").map { .character(String($0)) } }
        let punctuation = c(". , ? ! '")
        var bottom: [Key] = [page == .letters ? .page(.numbers) : .page(.letters)]
        if includeNextKeyboard { bottom.append(.nextKeyboard) }
        bottom += [.space, .returnKey]

        switch page {
        case .letters:
            return [
                c("q w e r t y u i o p"),
                c("a s d f g h j k l ç"),
                [.shift] + c("z x c v b n m") + [.delete],
                bottom,
            ]
        case .numbers:
            return [
                c("1 2 3 4 5 6 7 8 9 0"),
                c("- / : ; ( ) € & @ \""),
                [.page(.symbols)] + punctuation + [.delete],
                bottom,
            ]
        case .symbols:
            return [
                c("[ ] { } # % ^ * + ="),
                c("_ \ | ~ < > « » £ $"),
                [.page(.numbers)] + punctuation + [.delete],
                bottom,
            ]
        }
    }
}
