public enum Mood: String, CaseIterable, Codable, Sendable {
    case natural, simpatico, profissional, direto, descontraido

    public static let exampleInput = "boas, consegues me mandar isso quando tiveres tempo?"

    public var displayName: String {
        switch self {
        case .natural: return "Natural"
        case .simpatico: return "Simpático"
        case .profissional: return "Profissional"
        case .direto: return "Direto"
        case .descontraido: return "Descontraído"
        }
    }

    public var summary: String {
        switch self {
        case .natural: return "Mantém o teu tom, só corrige e aperfeiçoa"
        case .simpatico: return "Mais caloroso e próximo"
        case .profissional: return "Educado e cuidado, para trabalho e email"
        case .direto: return "Curto e claro"
        case .descontraido: return "Leve e com humor"
        }
    }

    public var exampleOutput: String {
        switch self {
        case .natural: return "Boas! Consegues mandar-me isso quando tiveres um bocadinho de tempo?"
        case .simpatico: return "Olá! 😊 Quando tiveres um tempinho, consegues mandar-me isso? Obrigado!"
        case .profissional: return "Olá, quando tiver disponibilidade, poderia enviar-me isso, por favor?"
        case .direto: return "Consegues mandar-me isso quando puderes?"
        case .descontraido: return "Boas! Quando tiveres um minutinho, manda-me isso aí, pode ser? 🙌"
        }
    }
}
