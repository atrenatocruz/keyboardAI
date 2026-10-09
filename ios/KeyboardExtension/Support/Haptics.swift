import UIKit

/// Haptics only work in keyboard extensions with Full Access; callers set `isEnabled` accordingly.
final class Haptics {
    var isEnabled = true
    private let tap = UIImpactFeedbackGenerator(style: .light)
    private let notification = UINotificationFeedbackGenerator()

    func prepare() {
        guard isEnabled else { return }
        tap.prepare()
        notification.prepare()
    }

    func keyTap() {
        guard isEnabled else { return }
        tap.impactOccurred()
        tap.prepare()
    }

    func success() {
        guard isEnabled else { return }
        notification.notificationOccurred(.success)
    }

    func error() {
        guard isEnabled else { return }
        notification.notificationOccurred(.error)
    }
}
