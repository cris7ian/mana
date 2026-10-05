import Foundation

public struct CodexCredentials: Sendable, Equatable {
    public let accessToken: String
    public let accountID: String

    public init(accessToken: String, accountID: String) {
        self.accessToken = accessToken
        self.accountID = accountID
    }
}

public struct CodexUsageClient: Sendable {
    public static let usageURL = URL(string: "https://chatgpt.com/backend-api/wham/usage")!
    public static let timeout: TimeInterval = 15
    public static let userAgent = "codexusage/1.0"
    private let transport: any HTTPTransport

    public init(transport: any HTTPTransport = URLSessionTransport(timeout: timeout)) {
        self.transport = transport
    }

    public func makeRequest(credentials: CodexCredentials) throws -> URLRequest {
        let token = credentials.accessToken.trimmingCharacters(in: .whitespacesAndNewlines)
        let accountID = credentials.accountID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { throw ProviderError.missingCredential(provider: .codex, field: "OAuth access token") }
        guard !accountID.isEmpty else { throw ProviderError.missingCredential(provider: .codex, field: "ChatGPT account ID") }
        var request = URLRequest(url: Self.usageURL, timeoutInterval: Self.timeout)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(accountID, forHTTPHeaderField: "ChatGPT-Account-Id")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        return request
    }

    public func fetch(credentials: CodexCredentials) async throws -> Data {
        try await transport.usageData(for: makeRequest(credentials: credentials))
    }

    public static func validate(statusCode: Int, retryAfter: TimeInterval?) throws {
        try HTTPResponse.validate(statusCode: statusCode, retryAfter: retryAfter)
    }
}
