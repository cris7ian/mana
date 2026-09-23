import Foundation

/// Reads only the provider fields used by codexusage and gousage.
/// Mana never writes these files or exposes their contents in UI or logs.
struct ProviderCredentialLoader: Sendable {
    let homeDirectory: URL

    init(homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) {
        self.homeDirectory = homeDirectory
    }

    func codexCredentials() throws -> CodexCredentials {
        let candidates: [(String, String)] = [
            (".pi/agent/auth.json", "openai-codex"),
            (".local/share/opencode/auth.json", "openai"),
            (".config/opencode/auth.json", "openai")
        ]
        for (path, provider) in candidates {
            let url = homeDirectory.appending(path: path)
            guard let data = try? Data(contentsOf: url),
                  let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let credentials = root[provider] as? [String: Any],
                  let access = credentials["access"] as? String,
                  let accountID = credentials["accountId"] as? String,
                  !access.isEmpty, !accountID.isEmpty else { continue }
            return CodexCredentials(accessToken: access, accountID: accountID)
        }
        throw ProviderError.missingCredential(provider: .codex, field: "personal ChatGPT Codex credentials in Pi or OpenCode auth files")
    }

    func openCodeGoCredentials() throws -> OpenCodeGoCredentials {
        let candidates = [".local/share/opencode/auth.json", ".config/opencode/auth.json"]
        for path in candidates {
            let url = homeDirectory.appending(path: path)
            guard let data = try? Data(contentsOf: url),
                  let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
            let go = root["opencode-go"] as? [String: Any]
            let generic = root["opencode"] as? [String: Any]
            if let key = go?["key"] as? String, !key.isEmpty {
                return OpenCodeGoCredentials(apiKey: key)
            }
            if let key = generic?["key"] as? String, !key.isEmpty {
                return OpenCodeGoCredentials(apiKey: key)
            }
        }
        throw ProviderError.missingCredential(provider: .openCodeGo, field: "OpenCode Go API key in OpenCode auth files")
    }
}
