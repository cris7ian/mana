import Foundation

public struct HTTPResponse: Sendable {
    public let data: Data
    public let statusCode: Int
    public let retryAfter: TimeInterval?

    public init(data: Data, statusCode: Int, retryAfter: TimeInterval?) {
        self.data = data
        self.statusCode = statusCode
        self.retryAfter = retryAfter
    }

    static func validate(statusCode: Int, retryAfter: TimeInterval?) throws {
        switch statusCode {
        case 200..<300: return
        case 401, 403: throw ProviderError.authentication(statusCode: statusCode)
        case 429: throw ProviderError.rateLimited(retryAfter: retryAfter)
        default: throw ProviderError.response(statusCode: statusCode)
        }
    }
}

public protocol HTTPTransport: Sendable {
    func send(_ request: URLRequest) async throws -> HTTPResponse
}

extension HTTPTransport {
    /// Both quota clients share cancellation, safe error messages, and HTTP classification.
    func usageData(for request: URLRequest) async throws -> Data {
        let response: HTTPResponse
        do { response = try await send(request) }
        catch is CancellationError { throw ProviderError.cancelled }
        catch let error as ProviderError { throw error }
        catch {
            if Task.isCancelled || (error as? URLError)?.code == .cancelled { throw ProviderError.cancelled }
            throw ProviderError.transport(ProviderError.transportDescription(for: error))
        }
        try HTTPResponse.validate(statusCode: response.statusCode, retryAfter: response.retryAfter)
        return response.data
    }
}

public struct URLSessionTransport: HTTPTransport {
    private let session: URLSession

    public init(timeout: TimeInterval = 15) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        configuration.httpShouldSetCookies = false
        session = URLSession(configuration: configuration)
    }

    public func send(_ request: URLRequest) async throws -> HTTPResponse {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ProviderError.malformedResponse
        }
        let rawRetryAfter = http.value(forHTTPHeaderField: "Retry-After")
        return HTTPResponse(data: data, statusCode: http.statusCode, retryAfter: RetryAfterParser.interval(rawRetryAfter))
    }
}
