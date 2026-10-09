public enum AIStatusMessage: Equatable, Sendable {
    case noFullAccess, offline, timeout, dailyLimit, tooLong, server, unchanged, contextChanged

    public var text: String {
        switch self {
        case .noFullAccess: return "Ativa o Acesso total para usar a IA"
        case .offline, .timeout: return "Sem ligação. Tenta outra vez."
        case .dailyLimit: return "Atingiste o limite de hoje"
        case .tooLong: return "Texto demasiado longo"
        case .server: return "Algo correu mal. Tenta outra vez."
        case .unchanged: return "✓ Já está ótimo"
        case .contextChanged: return "O texto mudou"
        }
    }
}
