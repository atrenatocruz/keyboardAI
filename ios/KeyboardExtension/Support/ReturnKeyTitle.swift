import UIKit

func returnKeyTitle(for type: UIReturnKeyType?) -> String {
    switch type {
    case .go: return "ir"
    case .search, .google, .yahoo: return "pesquisar"
    case .send: return "enviar"
    case .done: return "OK"
    case .next: return "seguinte"
    case .join: return "aderir"
    case .route: return "trajeto"
    case .continue: return "continuar"
    default: return "intro"
    }
}
