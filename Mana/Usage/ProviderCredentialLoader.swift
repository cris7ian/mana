import Foundation

/// Loads provider credentials from Mana's private local files.
struct ProviderCredentialLoader: Sendable {
    static let openCodeGoAccount = "opencode-go-api-key"
    private let store: any ProviderCredentialStoring

    init(store: any ProviderCredentialStoring = FileCredentialStore()) {
        self.store = store
    }

    func openCodeGoCredentials() throws -> OpenCodeGoCredentials {
        guard let data = try store.read(Self.openCodeGoAccount),
              let key = String(data: data, encoding: .utf8),
              !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ProviderError.missingCredential(provider: .openCodeGo, field: "API key")
        }
        return OpenCodeGoCredentials(apiKey: key)
    }

    func saveOpenCodeGoAPIKey(_ key: String) throws {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ProviderError.missingCredential(provider: .openCodeGo, field: "API key")
        }
        try store.write(Data(trimmed.utf8), account: Self.openCodeGoAccount)
    }

    func hasOpenCodeGoAPIKey() -> Bool {
        (try? store.read(Self.openCodeGoAccount)) != nil
    }

    func openCodeGoAPIKey() throws -> String? {
        guard let data = try store.read(Self.openCodeGoAccount) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func removeOpenCodeGoAPIKey() throws {
        try store.remove(Self.openCodeGoAccount)
    }
}
