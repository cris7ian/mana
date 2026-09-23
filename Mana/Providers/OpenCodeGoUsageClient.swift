import Foundation

struct OpenCodeGoCredentials: Sendable, Equatable {
    let apiKey: String
}

struct OpenCodeGoUsageClient: Sendable {
    static let usageURL = URL(string: "https://opencode.ai/zen/go/v1/usage")!
    static let timeout: TimeInterval = 15
    static let userAgent = "gousage/1.0"
    private let transport: any HTTPTransport

    init(transport: any HTTPTransport = URLSessionTransport(timeout: timeout)) {
        self.transport = transport
    }

    func makeRequest(credentials: OpenCodeGoCredentials) throws -> URLRequest {
        let key = credentials.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw ProviderError.missingCredential(provider: .openCodeGo, field: "API key") }
        var request = URLRequest(url: Self.usageURL, timeoutInterval: Self.timeout)
        request.httpMethod = "GET"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        return request
    }

    func fetch(credentials: OpenCodeGoCredentials) async throws -> Data {
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
