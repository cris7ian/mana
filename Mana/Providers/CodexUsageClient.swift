import Foundation

struct CodexCredentials: Sendable, Equatable {
    let accessToken: String
    let accountID: String
}

struct CodexUsageClient: Sendable {
    static let usageURL = URL(string: "https://chatgpt.com/backend-api/wham/usage")!
    static let timeout: TimeInterval = 15
    static let userAgent = "codexusage/1.0"
    private let transport: any HTTPTransport

    init(transport: any HTTPTransport = URLSessionTransport(timeout: timeout)) {
        self.transport = transport
    }

    func makeRequest(credentials: CodexCredentials) throws -> URLRequest {
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

    func fetch(credentials: CodexCredentials) async throws -> Data {
        let response: HTTPResponse
        do { response = try await transport.send(makeRequest(credentials: credentials)) }
        catch is CancellationError { throw ProviderError.cancelled }
        catch let error as ProviderError { throw error }
        catch { throw ProviderError.transport(ProviderError.transportDescription(for: error)) }
        try Self.validate(statusCode: response.statusCode, retryAfter: response.retryAfter)
        return response.data
    }

    static func validate(statusCode: Int, retryAfter: TimeInterval?) throws {
        if (200..<300).contains(statusCode) { return }
        if statusCode == 401 || statusCode == 403 { throw ProviderError.authentication(statusCode: statusCode) }
        if statusCode == 429 { throw ProviderError.rateLimited(retryAfter: retryAfter) }
        throw ProviderError.response(statusCode: statusCode)
    }
}
