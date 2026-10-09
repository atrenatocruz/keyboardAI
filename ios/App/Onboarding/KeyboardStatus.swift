import Foundation

enum KeyboardStatus {
    static let extensionBundleID = "com.renatocruz.keyboardai.keyboard"

    /// Best-effort check: iOS lists enabled keyboards in the global "AppleKeyboards" defaults key.
    /// If this ever stops working, the onboarding still offers a manual "Já adicionei" button.
    static func isKeyboardAdded() -> Bool {
        let keyboards = UserDefaults.standard.object(forKey: "AppleKeyboards") as? [String] ?? []
        return keyboards.contains(extensionBundleID)
    }
}
