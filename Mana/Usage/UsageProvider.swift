import Foundation

protocol UsageProviding: Sendable {
    var provider: ProviderID { get }
    func fetchSnapshot() async throws -> ProviderSnapshot
}

struct CodexUsageProvider: UsageProviding {
    let provider: ProviderID = .codex
    let oauth: CodexOAuthClient
    let client: CodexUsageClient

    init(oauth: CodexOAuthClient, transport: any HTTPTransport = URLSessionTransport()) {
        self.oauth = oauth
        self.client = CodexUsageClient(transport: transport)
    }

    func fetchSnapshot() async throws -> ProviderSnapshot {
        let data = try await client.fetch(credentials: oauth.credentials())
        return try CodexUsageDecoder.decode(data)
    }
}

struct OpenCodeGoUsageProvider: UsageProviding {
    let provider: ProviderID = .openCodeGo
    let loader: ProviderCredentialLoader
    let client: OpenCodeGoUsageClient

    init(loader: ProviderCredentialLoader = ProviderCredentialLoader(), transport: any HTTPTransport = URLSessionTransport()) {
        self.loader = loader
        self.client = OpenCodeGoUsageClient(transport: transport)
    }

    func fetchSnapshot() async throws -> ProviderSnapshot {
        let data = try await client.fetch(credentials: loader.openCodeGoCredentials())
        return try OpenCodeGoUsageDecoder.decode(data)
    }
}
