import UIKit
import KeyboardCore

final class KeyboardViewController: UIInputViewController {
    override func loadView() {
        let input = UIInputView(frame: .zero, inputViewStyle: .keyboard)
        input.allowsSelfSizing = true
        inputView = input
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let label = UILabel()
        label.text = "KeyboardAI · \(Mood.natural.displayName)"
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            view.heightAnchor.constraint(equalToConstant: 260),
        ])
    }
}
