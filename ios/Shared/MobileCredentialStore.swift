import Foundation
import Security

protocol MobileCredentialStoring: Sendable {
    func read(_ account: String) throws -> Data?
    func write(_ data: Data, account: String) throws
    func remove(_ account: String) throws
}

enum MobileStorageError: Error, LocalizedError {
    case unavailable, locked, invalidData, busy, accountChanged
    case keychain(status: Int32)

    var errorDescription: String? {
        switch self {
        case .unavailable: String(localized: "Secure storage is unavailable. Open Mana after unlocking your iPhone.")
        case .locked: String(localized: "Unlock your iPhone to access this provider.")
        case .invalidData: String(localized: "Saved provider data could not be read. Reconnect this provider in Settings.")
        case .busy: String(localized: "Another refresh is in progress. Try again shortly.")
        case .accountChanged: String(localized: "This provider changed while the request was running.")
        case .keychain: String(localized: "Secure credential storage is unavailable. Check the app's signing configuration.")
        }
    }
}

struct MobileKeychainStore: MobileCredentialStoring {
    private let accessGroup: String?
    private let hasValidConfiguration: Bool
    private let service = "com.salsaparapizza.mana.ios.credentials"

    init() {
        // Use the signing-expanded value, not a hard-coded team prefix. Unsigned simulator
        // builds use their default Keychain group; signed app and extension use the shared group.
        let value = Bundle.main.object(forInfoDictionaryKey: "ManaKeychainAccessGroup") as? String
        #if targetEnvironment(simulator)
        // Unsigned simulator builds have no shared Keychain entitlement. They can
        // exercise local credential storage; cross-target sharing requires device signing.
        accessGroup = nil
        hasValidConfiguration = true
        #else
        accessGroup = value
        hasValidConfiguration = value?.range(of: "^[A-Z0-9]{10}\\.com\\.salsaparapizza\\.mana\\.ios\\.shared$", options: .regularExpression) != nil
        #endif
    }

    private func query(_ account: String) throws -> [String: Any] {
        guard hasValidConfiguration else { throw MobileStorageError.unavailable }
        var result: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: service,
                                    kSecAttrAccount as String: account,
                                    kSecAttrSynchronizable as String: false]
        if let accessGroup { result[kSecAttrAccessGroup as String] = accessGroup }
        return result
    }

    func read(_ account: String) throws -> Data? {
        var request = try query(account)
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(request as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        try check(status)
        guard let data = result as? Data else { throw MobileStorageError.invalidData }
        return data
    }

    func write(_ data: Data, account: String) throws {
        let request = try query(account)
        let attributes: [String: Any] = [kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
        let status = SecItemUpdate(request as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound { try check(SecItemAdd((request.merging(attributes) { _, new in new }) as CFDictionary, nil)) }
        else { try check(status) }
    }

    func remove(_ account: String) throws {
        let request = try query(account)
        let status = SecItemDelete(request as CFDictionary)
        if status != errSecItemNotFound { try check(status) }
    }

    private func check(_ status: OSStatus) throws {
        if status == errSecInteractionNotAllowed || status == errSecNotAvailable { throw MobileStorageError.locked }
        guard status == errSecSuccess else { throw MobileStorageError.keychain(status: status) }
    }
}
