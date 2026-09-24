import Foundation

protocol ProviderCredentialStoring: Sendable {
    func read(_ account: String) throws -> Data?
    func write(_ data: Data, account: String) throws
    func remove(_ account: String) throws
}

/// Local credentials, scoped to the current macOS user. No Keychain or provider auth files.
struct FileCredentialStore: ProviderCredentialStoring {
    let directory: URL

    init(directory: URL = FileManager.default.homeDirectoryForCurrentUser
        .appending(path: "Library/Application Support/Mana/credentials")) {
        self.directory = directory
    }

    func read(_ account: String) throws -> Data? {
        let file = try url(for: account)
        guard FileManager.default.fileExists(atPath: file.path) else { return nil }
        try validatePrivateDirectory()
        let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
        guard attributes[.type] as? FileAttributeType == .typeRegular,
              let permissions = attributes[.posixPermissions] as? Int,
              permissions & 0o077 == 0 else { throw CredentialStoreError.insecurePermissions }
        return try Data(contentsOf: file)
    }

    func write(_ data: Data, account: String) throws {
        let file = try url(for: account)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700])
        try validatePrivateDirectory()
        // Atomic replacement happens inside a 0700 directory. Restrict the new file to 0600.
        try data.write(to: file, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
    }

    func remove(_ account: String) throws {
        let file = try url(for: account)
        guard FileManager.default.fileExists(atPath: file.path) else { return }
        try validatePrivateDirectory()
        try FileManager.default.removeItem(at: file)
    }

    private func url(for account: String) throws -> URL {
        let name: String
        switch account {
        case "openai-codex-oauth": name = "codex-oauth.json"
        case "opencode-go-api-key": name = "opencode-go-key"
        default: throw CredentialStoreError.invalidAccount
        }
        return directory.appending(path: name)
    }

    private func validatePrivateDirectory() throws {
        let attributes = try FileManager.default.attributesOfItem(atPath: directory.path)
        guard attributes[.type] as? FileAttributeType == .typeDirectory,
              let permissions = attributes[.posixPermissions] as? Int,
              permissions & 0o077 == 0 else { throw CredentialStoreError.insecurePermissions }
    }
}

enum CredentialStoreError: Error, LocalizedError {
    case invalidAccount, insecurePermissions

    var errorDescription: String? {
        "Could not access Mana credentials. Check the credentials directory permissions."
    }
}
