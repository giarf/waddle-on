import Foundation
import Security

struct AIKeychainError: Error, LocalizedError {
    let status: OSStatus

    var errorDescription: String? {
        "No se pudo acceder a la clave API en el Llavero (estado \(status))."
    }
}

final class SettingsStore {
    private let defaults: UserDefaults
    private let keychainService: String
    private let keychainAccount = "openai-api-key"

    init(defaults: UserDefaults = .standard, keychainService: String = "com.waddleon.ai") {
        self.defaults = defaults
        self.keychainService = keychainService
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

    func loadAPIKey() throws -> String {
        var query = keychainQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return "" }
        guard status == errSecSuccess else { throw AIKeychainError(status: status) }
        guard let data = result as? Data, let key = String(data: data, encoding: .utf8) else {
            throw AIKeychainError(status: errSecDecode)
        }
        return key
    }

    /// Saving an empty key removes the credential; other settings never contain it.
    func saveAPIKey(_ apiKey: String) throws {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if key.isEmpty {
            let status = SecItemDelete(keychainQuery as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else {
                throw AIKeychainError(status: status)
            }
            return
        }
        let data = Data(key.utf8)
        let status = SecItemUpdate(keychainQuery as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var item = keychainQuery
            item[kSecValueData as String] = data
            item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let addStatus = SecItemAdd(item as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw AIKeychainError(status: addStatus) }
        } else if status != errSecSuccess {
            throw AIKeychainError(status: status)
        }
    }

    private var keychainQuery: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: keychainService,
         kSecAttrAccount as String: keychainAccount]
    }
}
