import Foundation

public final class SettingsStore {
    private enum Keys {
        static let installID = "installID"
        static let mood = "mood"
        static let haptics = "hapticsEnabled"
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var installID: String {
        if let existing = defaults.string(forKey: Keys.installID) { return existing }
        let id = UUID().uuidString.lowercased()
        defaults.set(id, forKey: Keys.installID)
        return id
    }

    public var mood: Mood {
        get { Mood(rawValue: defaults.string(forKey: Keys.mood) ?? "") ?? .natural }
        set { defaults.set(newValue.rawValue, forKey: Keys.mood) }
    }

    public var hapticsEnabled: Bool {
        get { defaults.object(forKey: Keys.haptics) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Keys.haptics) }
    }
}
