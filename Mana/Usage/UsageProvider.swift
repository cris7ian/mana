import Foundation

protocol UsageProviding: Sendable {
    var provider: ProviderID { get }
    func fetchSnapshot() async throws -> ProviderSnapshot
}

struct CodexUsageProvider: UsageProviding {
    let provider: ProviderID = .codex
    let loader: ProviderCredentialLoader
    let client: CodexUsageClient

    init(loader: ProviderCredentialLoader = ProviderCredentialLoader(), transport: any HTTPTransport = URLSessionTransport()) {
        self.loader = loader
        self.client = CodexUsageClient(transport: transport)
    }

    func fetchSnapshot() async throws -> ProviderSnapshot {
        let data = try await client.fetch(credentials: loader.codexCredentials())
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
