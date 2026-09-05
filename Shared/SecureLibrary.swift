import Foundation
import Security
import VPNCore

enum SecureLibrary {
    private static var query: [String: Any] {
        get throws {
            // Both signatures must list the SAME shared group first. Using the signed
            // default group avoids hard-coding a Team ID into an IPA signed later on PC.
            return [kSecClass as String: kSecClassGenericPassword,
                    kSecAttrService as String: "Velora.Library.v1",
                    kSecAttrAccount as String: "profiles"]
        }
    }

    static func load() throws -> LibraryState {
        var request = try query
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(request as CFDictionary, &result)
        if status == errSecItemNotFound { return LibraryState() }
        guard status == errSecSuccess, let data = result as? Data else { throw StorageError.keychain(status) }
        return try JSONDecoder().decode(LibraryState.self, from: data)
    }

    static func save(_ state: LibraryState) throws {
        let data = try JSONEncoder().encode(state)
        let request = try query
        let values: [String: Any] = [kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
        var status = SecItemUpdate(request as CFDictionary, values as CFDictionary)
        if status == errSecItemNotFound {
            status = SecItemAdd(request.merging(values) { _, new in new } as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw StorageError.keychain(status) }
    }

    enum StorageError: LocalizedError {
        case configuration, keychain(OSStatus)
        var errorDescription: String? {
            switch self {
            case .configuration: return "Не настроена общая группа Keychain для приложения и VPN-расширения."
            case .keychain(let code): return "Keychain недоступен (\(code)). Проверьте подпись и общую группу доступа у приложения и расширения."
            }
        }
    }
}
