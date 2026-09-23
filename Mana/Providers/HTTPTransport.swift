import Foundation

struct HTTPResponse: Sendable {
    let data: Data
    let statusCode: Int
    let retryAfter: TimeInterval?
}

protocol HTTPTransport: Sendable {
    func send(_ request: URLRequest) async throws -> HTTPResponse
}

struct URLSessionTransport: HTTPTransport {
    private let session: URLSession

    init(timeout: TimeInterval = 15) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        configuration.httpShouldSetCookies = false
        session = URLSession(configuration: configuration)
    }

    func send(_ request: URLRequest) async throws -> HTTPResponse {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ProviderError.malformedResponse
        }
        let rawRetryAfter = http.value(forHTTPHeaderField: "Retry-After")
        return HTTPResponse(data: data, statusCode: http.statusCode, retryAfter: RetryAfterParser.interval(rawRetryAfter))
    }
}
