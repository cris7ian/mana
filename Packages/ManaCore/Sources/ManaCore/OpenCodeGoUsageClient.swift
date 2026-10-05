import Foundation

public struct OpenCodeGoCredentials: Sendable, Equatable {
    public let apiKey: String

    public init(apiKey: String) {
        self.apiKey = apiKey
    }
}

public struct OpenCodeGoUsageClient: Sendable {
    public static let usageURL = URL(string: "https://opencode.ai/zen/go/v1/usage")!
    public static let timeout: TimeInterval = 15
    public static let userAgent = "gousage/1.0"
    private let transport: any HTTPTransport

    public init(transport: any HTTPTransport = URLSessionTransport(timeout: timeout)) {
        self.transport = transport
    }

    public func makeRequest(credentials: OpenCodeGoCredentials) throws -> URLRequest {
        let key = credentials.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw ProviderError.missingCredential(provider: .openCodeGo, field: "API key") }
        var request = URLRequest(url: Self.usageURL, timeoutInterval: Self.timeout)
        request.httpMethod = "GET"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        return request
    }

    public func fetch(credentials: OpenCodeGoCredentials) async throws -> Data {
        try await transport.usageData(for: makeRequest(credentials: credentials))
    }

    public static func validate(statusCode: Int, retryAfter: TimeInterval?) throws {
        try HTTPResponse.validate(statusCode: statusCode, retryAfter: retryAfter)
    }
}
