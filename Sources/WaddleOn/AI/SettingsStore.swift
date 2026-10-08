import Foundation

final class SettingsStore {
    private let defaults: UserDefaults

    var followsMouse: Bool {
        get { defaults.object(forKey: "desktop.followsMouse") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "desktop.followsMouse") }
    }

    var snowballsEnabled: Bool {
        get { defaults.object(forKey: "desktop.snowballsEnabled") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "desktop.snowballsEnabled") }
    }

    var snowballInterval: Double {
        get { Self.validInterval(defaults.object(forKey: "desktop.snowballInterval") as? Double ?? 20) }
        set { defaults.set(Self.validInterval(newValue), forKey: "desktop.snowballInterval") }
    }

    private static func validInterval(_ value: Double) -> Double {
        value.isFinite ? min(300, max(5, value)) : 20
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadConfiguration() -> AIConfiguration {
        let fallback = AIConfiguration()
        return AIConfiguration(
            baseURL: defaults.string(forKey: "ai.baseURL") ?? fallback.baseURL,
            model: defaults.string(forKey: "ai.model") ?? fallback.model,
            systemPrompt: defaults.string(forKey: "ai.systemPrompt") ?? fallback.systemPrompt
        )
    }

    func saveConfiguration(_ configuration: AIConfiguration) {
        defaults.set(configuration.baseURL, forKey: "ai.baseURL")
        defaults.set(configuration.model, forKey: "ai.model")
        defaults.set(configuration.systemPrompt, forKey: "ai.systemPrompt")
    }

    func loadAPIKey() -> String {
        defaults.string(forKey: "ai.apiKey") ?? ""
    }

    /// Stored locally without encryption, by user preference. Never access the
    /// previous Keychain entry: even migration can trigger a password prompt.
    func saveAPIKey(_ apiKey: String) {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if key.isEmpty {
            defaults.removeObject(forKey: "ai.apiKey")
            return
        }
        defaults.set(key, forKey: "ai.apiKey")
    }
}
