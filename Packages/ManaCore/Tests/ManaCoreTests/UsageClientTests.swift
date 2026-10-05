import Foundation
import Testing
import ManaCore

@Test(arguments: [ProviderID.codex, .openCodeGo])
func URLSessionCancellationRemainsTypedCancellation(provider: ProviderID) async {
    let transport = StubTransport { _ in throw URLError(.cancelled) }
    do {
        _ = try await fetch(provider, transport: transport)
        Issue.record("Cancellation must throw")
    } catch let error as ProviderError {
        #expect(error == .cancelled)
    } catch {
        Issue.record("Expected typed cancellation")
    }
}

@Test func openCodeGoClientFetchesAndDecodesThroughInjectedTransport() async throws {
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let transport = StubTransport { request in
        #expect(request.url?.absoluteString == "https://opencode.ai/zen/go/v1/usage")
        #expect(request.httpMethod == "GET")
        #expect(request.timeoutInterval == 15)
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer synthetic-test-key")
        #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
        #expect(request.value(forHTTPHeaderField: "User-Agent") == "gousage/1.0")
        let data = Data(#"{"usage":{"rolling":{"status":"exhausted","percent":100},"weekly":{"status":"ok","percent":true,"resetsAt":"unavailable"}}}"#.utf8)
        return HTTPResponse(data: data, statusCode: 200, retryAfter: nil)
    }
    let client = OpenCodeGoUsageClient(transport: transport)
    let data = try await client.fetch(credentials: OpenCodeGoCredentials(apiKey: "  synthetic-test-key\n"))
    let snapshot = try OpenCodeGoUsageDecoder.decode(data, now: now)

    #expect(snapshot.provider == .openCodeGo)
    #expect(snapshot.receivedAt == now)
    #expect(snapshot.windows.map(\.content) == [.blocked("exhausted"), .unknownPercent, .missing])
    #expect(snapshot.windows[1].resetAt == nil)
    #expect(snapshot.windows[1].resetText == "unavailable")
}

@Test func codexClientFetchesAndDecodesThroughInjectedTransport() async throws {
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let transport = StubTransport { request in
        #expect(request.url?.absoluteString == "https://chatgpt.com/backend-api/wham/usage")
        #expect(request.httpMethod == "GET")
        #expect(request.timeoutInterval == 15)
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer synthetic-test-token")
        #expect(request.value(forHTTPHeaderField: "ChatGPT-Account-Id") == "synthetic-test-account")
        #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
        #expect(request.value(forHTTPHeaderField: "User-Agent") == "codexusage/1.0")
        let data = Data(#"{"rate_limit":{"allowed":false,"primary_window":{"limit_window_seconds":604800,"used_percent":true,"reset_at":"invalid"}}}"#.utf8)
        return HTTPResponse(data: data, statusCode: 200, retryAfter: nil)
    }
    let client = CodexUsageClient(transport: transport)
    let data = try await client.fetch(credentials: CodexCredentials(
        accessToken: "  synthetic-test-token\n", accountID: " synthetic-test-account "
    ))
    let snapshot = try CodexUsageDecoder.decode(data, now: now)

    #expect(snapshot.provider == .codex)
    #expect(snapshot.receivedAt == now)
    #expect(snapshot.isBlocked)
    #expect(snapshot.blockedReason != nil)
    #expect(snapshot.windows[0].label == "1w")
    #expect(snapshot.windows[0].content == .unknownPercent)
    #expect(snapshot.windows[0].resetAt == nil)
    #expect(snapshot.windows[0].resetText == "invalid")
    #expect(snapshot.windows[1].content == .missing)
}

@Test(arguments: [ProviderID.codex, .openCodeGo], [401, 403, 429, 500])
func clientsClassifyHTTPFailuresWithoutRetainingResponseBodies(provider: ProviderID, statusCode: Int) async {
    let transport = StubTransport { _ in
        HTTPResponse(data: Data("synthetic-response-body".utf8), statusCode: statusCode, retryAfter: 120)
    }
    do {
        _ = try await fetch(provider, transport: transport)
        Issue.record("Expected the HTTP failure to throw")
    } catch let error as ProviderError {
        switch statusCode {
        case 401, 403: #expect(error == .authentication(statusCode: statusCode))
        case 429: #expect(error == .rateLimited(retryAfter: 120))
        default: #expect(error == .response(statusCode: statusCode))
        }
        #expect(!error.localizedDescription.contains("synthetic-response-body"))
    } catch {
        Issue.record("Expected a typed provider error")
    }
}

@Test(arguments: [ProviderID.codex, .openCodeGo])
func clientsSanitizeTransportErrorMessages(provider: ProviderID) async {
    let transport = StubTransport { _ in
        throw URLError(.timedOut, userInfo: [NSLocalizedDescriptionKey: "synthetic-private-error-details"])
    }
    do {
        _ = try await fetch(provider, transport: transport)
        Issue.record("Expected the transport failure to throw")
    } catch let error as ProviderError {
        #expect(error == .transport("request timed out"))
        #expect(!error.localizedDescription.contains("synthetic-private-error-details"))
    } catch {
        Issue.record("Expected a typed provider error")
    }
}

@Test(arguments: ["", " \n "])
func clientsRejectMissingCredentialsBeforeSending(value: String) async {
    let transport = StubTransport { _ in
        Issue.record("Missing credentials must not reach the transport")
        throw URLError(.badURL)
    }
    await #expect(throws: ProviderError.missingCredential(provider: .codex, field: "OAuth access token")) {
        _ = try await CodexUsageClient(transport: transport).fetch(credentials: .init(accessToken: value, accountID: "synthetic-account"))
    }
    await #expect(throws: ProviderError.missingCredential(provider: .codex, field: "ChatGPT account ID")) {
        _ = try await CodexUsageClient(transport: transport).fetch(credentials: .init(accessToken: "synthetic-test-token", accountID: value))
    }
    await #expect(throws: ProviderError.missingCredential(provider: .openCodeGo, field: "API key")) {
        _ = try await OpenCodeGoUsageClient(transport: transport).fetch(credentials: .init(apiKey: value))
    }
}

private func fetch(_ provider: ProviderID, transport: any HTTPTransport) async throws -> Data {
    if provider == .codex {
        return try await CodexUsageClient(transport: transport).fetch(credentials: .init(accessToken: "synthetic-test-token", accountID: "synthetic-account"))
    }
    return try await OpenCodeGoUsageClient(transport: transport).fetch(credentials: .init(apiKey: "synthetic-test-key"))
}

private struct StubTransport: HTTPTransport {
    let handler: @Sendable (URLRequest) async throws -> HTTPResponse

    func send(_ request: URLRequest) async throws -> HTTPResponse {
        try await handler(request)
    }
}
