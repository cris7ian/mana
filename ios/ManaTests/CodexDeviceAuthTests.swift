import Foundation
import ManaCore
import XCTest
@testable import ManaIOS

final class CodexDeviceAuthTests: XCTestCase {
    func testBeginRequestsPublicClientAndUsesFixedVerificationURL() async throws {
        let clock = AuthTestClock()
        let transport = AuthTestTransport([response(codeResponse(interval: "3"))])
        let auth = CodexDeviceAuth(transport: transport, now: { clock.now() })
        let authorization = try await auth.begin()
        XCTAssertEqual(authorization.verificationURL.absoluteString, "https://auth.openai.com/codex/device")
        XCTAssertEqual(authorization.interval, 3)
        XCTAssertEqual(authorization.expiresAt, clock.now().addingTimeInterval(900))
        let requests = await transport.requests
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(requests[0].url?.absoluteString, "https://auth.openai.com/api/accounts/deviceauth/usercode")
        XCTAssertEqual(requests[0].httpMethod, "POST")
        XCTAssertEqual(requests[0].value(forHTTPHeaderField: "Content-Type"), "application/json")
        let body = try json(requests[0])
        XCTAssertEqual(body["client_id"] as? String, "app_EMoamEEZ73f0CkXaXp7hrann")
    }

    func testUsercodeAliasAndIntervalBounds() async throws {
        for (interval, expected) in [(nil, 5.0), ("0", 5), ("-1", 5), ("bad", 5), ("1000", 900), ("0.5", 1)] {
            var body = codeResponse(interval: interval)
            body["usercode"] = body.removeValue(forKey: "user_code")
            let authorization = try await CodexDeviceAuth(transport: AuthTestTransport([response(body)])).begin()
            XCTAssertEqual(authorization.interval, expected)
        }
        let authorization = try await CodexDeviceAuth(transport: AuthTestTransport([
            response(codeResponse(interval: 7))
        ])).begin()
        XCTAssertEqual(authorization.interval, 7)
    }

    func testServerPollingIntervalIsNotShortened() async throws {
        let transport = AuthTestTransport([response(codeResponse(interval: "60"))])
        let authorization = try await CodexDeviceAuth(transport: transport).begin()
        XCTAssertEqual(authorization.interval, 60)
    }

    func testInterruptedPollingKeepsTheCodeAndIssuerInterval() async throws {
        let clock = AuthTestClock()
        let transport = AuthTestTransport(results: [
            .failure(.cancelled), .failure(.networkConnectionLost),
            .response(response([:], status: 403)), .response(response(approval())), .response(response(tokenResponse()))
        ])
        let supplied = DeviceAuthorization(userCode: "TEST-CODE", verificationURL: URL(string: "https://auth.openai.com/codex/device")!,
                                           deviceAuthID: UUID().uuidString, interval: 60, expiresAt: clock.now().addingTimeInterval(900))
        let auth = CodexDeviceAuth(transport: transport, now: { clock.now() }, sleep: { clock.advance($0) })
        let tokens = try await auth.complete(supplied)
        XCTAssertEqual(tokens.accountID, "synthetic-account")
        XCTAssertEqual(clock.now(), Date(timeIntervalSince1970: 1180))
        let requests = await transport.requests
        XCTAssertEqual(requests.count, 5)
        for request in requests.prefix(4) {
            XCTAssertTrue(try json(request)["device_auth_id"] as? String == supplied.deviceAuthID)
            XCTAssertEqual(try json(request)["user_code"] as? String, "TEST-CODE")
        }
    }

    func testInterruptedPollingStopsAtOriginalExpiry() async throws {
        let clock = AuthTestClock()
        let transport = AuthTestTransport(results: [.failure(.cancelled), .failure(.timedOut)])
        let auth = CodexDeviceAuth(transport: transport, now: { clock.now() }, sleep: { clock.advance($0) })
        do {
            _ = try await auth.complete(authorization(clock: clock, expiresIn: 6))
            XCTFail("An interrupted request must not extend the approval lifetime")
        } catch CodexDeviceAuthError.expired { }
        XCTAssertEqual(clock.now(), Date(timeIntervalSince1970: 1006))
        let requests = await transport.requests
        XCTAssertEqual(requests.count, 2)
    }

    func testExplicitCancellationDuringInterruptedPollStopsRetrying() async throws {
        let transport = AuthTestTransport(results: [.failure(.cancelled)])
        let waiting = expectation(description: "Retry wait started")
        let auth = CodexDeviceAuth(transport: transport, sleep: { _ in
            waiting.fulfill()
            try await Task.sleep(for: .seconds(60))
        })
        let supplied = authorization(clock: AuthTestClock(date: .now))
        let task = Task { try await auth.complete(supplied) }
        await fulfillment(of: [waiting], timeout: 2)
        task.cancel()
        do {
            _ = try await task.value
            XCTFail("Explicit Cancel must not retry sign-in")
        } catch is CancellationError { }
        let requests = await transport.requests
        XCTAssertEqual(requests.count, 1)
    }

    func testInterruptedApprovedExchangeDoesNotRepollOrRequestANewCode() async throws {
        let clock = AuthTestClock()
        let transport = AuthTestTransport(results: [
            .response(response(approval())), .failure(.cancelled), .response(response(tokenResponse()))
        ])
        let auth = CodexDeviceAuth(transport: transport, now: { clock.now() }, sleep: { clock.advance($0) })
        _ = try await auth.complete(authorization(clock: clock))
        XCTAssertEqual(clock.now(), Date(timeIntervalSince1970: 1005))
        let requests = await transport.requests
        XCTAssertEqual(requests.map { $0.url?.path }, ["/api/accounts/deviceauth/token", "/oauth/token", "/oauth/token"])
        XCTAssertTrue(requests[1].httpBody == requests[2].httpBody)
    }

    func testPendingThenApprovalExchangesCodeWithCorrectFormEncoding() async throws {
        let clock = AuthTestClock()
        let transport = AuthTestTransport([
            response([:], status: 403), response([:], status: 404), response(approval()), response(tokenResponse())
        ])
        let auth = CodexDeviceAuth(transport: transport, now: { clock.now() }, sleep: { clock.advance($0) })
        let tokens = try await auth.complete(authorization(clock: clock))
        XCTAssertEqual(tokens.accountID, "synthetic-account")
        XCTAssertEqual(tokens.expiresAt, clock.now().addingTimeInterval(3600))
        let requests = await transport.requests
        XCTAssertEqual(requests.count, 4)
        XCTAssertEqual(requests[0].url?.path, "/api/accounts/deviceauth/token")
        XCTAssertNotNil(try json(requests[0])["device_auth_id"])
        XCTAssertNotNil(try json(requests[0])["user_code"])
        XCTAssertEqual(requests[3].url?.path, "/oauth/token")
        XCTAssertEqual(requests[3].value(forHTTPHeaderField: "Content-Type"), "application/x-www-form-urlencoded")
        let fields = form(requests[3])
        XCTAssertEqual(fields["grant_type"], "authorization_code")
        XCTAssertEqual(fields["redirect_uri"], "https://auth.openai.com/deviceauth/callback")
        XCTAssertTrue(fields["code"] == approval()["authorization_code"] as? String)
        XCTAssertTrue(fields["code_verifier"] == approval()["code_verifier"] as? String)
        XCTAssertFalse(String(decoding: requests[3].httpBody ?? Data(), as: UTF8.self).contains("code=synthetic+"))
    }

    func testExpiryStopsPollingAtDeadline() async throws {
        let clock = AuthTestClock()
        let transport = AuthTestTransport([response([:], status: 403), response([:], status: 404)])
        let auth = CodexDeviceAuth(transport: transport, now: { clock.now() }, sleep: { clock.advance($0) })
        do {
            _ = try await auth.complete(authorization(clock: clock, expiresIn: 6))
            XCTFail("Expired authorization must fail")
        } catch CodexDeviceAuthError.expired { }
        let requests = await transport.requests
        XCTAssertEqual(requests.count, 2)
        XCTAssertEqual(clock.now(), Date(timeIntervalSince1970: 1006))
    }

    func testAlreadyExpiredAuthorizationMakesNoRequest() async throws {
        let clock = AuthTestClock()
        let transport = AuthTestTransport([])
        do {
            _ = try await CodexDeviceAuth(transport: transport, now: { clock.now() })
                .complete(authorization(clock: clock, expiresIn: 0))
            XCTFail("Expired authorization must fail")
        } catch CodexDeviceAuthError.expired { }
        let requests = await transport.requests
        XCTAssertTrue(requests.isEmpty)
    }

    func testPollingNeverExceedsFifteenMinutesWithLongerSuppliedExpiry() async throws {
        let clock = AuthTestClock()
        let transport = AuthTestTransport(Array(repeating: response([:], status: 404), count: 30))
        let auth = CodexDeviceAuth(transport: transport, now: { clock.now() }, sleep: { clock.advance($0) })
        let supplied = DeviceAuthorization(userCode: "TEST-CODE",
            verificationURL: URL(string: "https://auth.openai.com/codex/device")!, deviceAuthID: UUID().uuidString,
            interval: 30, expiresAt: clock.now().addingTimeInterval(3600))
        do {
            _ = try await auth.complete(supplied)
            XCTFail("Polling must stop after fifteen minutes")
        } catch CodexDeviceAuthError.expired { }
        let requests = await transport.requests
        XCTAssertEqual(requests.count, 30)
        XCTAssertEqual(clock.now(), Date(timeIntervalSince1970: 1900))
    }

    func testInvalidAuthorizationAndRefreshInputMakeNoRequest() async throws {
        let clock = AuthTestClock()
        let transport = AuthTestTransport([])
        let auth = CodexDeviceAuth(transport: transport, now: { clock.now() })
        let supplied = DeviceAuthorization(userCode: "TEST-CODE",
            verificationURL: URL(string: "https://auth.openai.com/codex/device")!, deviceAuthID: UUID().uuidString,
            interval: 5, expiresAt: Date(timeIntervalSince1970: .infinity))
        do {
            _ = try await auth.complete(supplied)
            XCTFail("Non-finite expiration must fail")
        } catch CodexDeviceAuthError.invalidResponse { }
        let tokens = CodexMobileTokens(accessToken: UUID().uuidString, refreshToken: "", accountID: "synthetic-account",
                                       expiresAt: clock.now())
        do {
            _ = try await auth.refresh(tokens)
            XCTFail("Empty refresh token must fail")
        } catch CodexDeviceAuthError.invalidResponse { }
        let requests = await transport.requests
        XCTAssertTrue(requests.isEmpty)
    }

    func testCancellationDuringPendingWaitStopsPolling() async throws {
        let transport = AuthTestTransport([response([:], status: 403)])
        let waiting = expectation(description: "Pending wait started")
        let auth = CodexDeviceAuth(transport: transport, sleep: { _ in
            waiting.fulfill()
            try await Task.sleep(for: .seconds(60))
        })
        let authorization = authorization(clock: AuthTestClock(date: Date()))
        let task = Task { try await auth.complete(authorization) }
        await fulfillment(of: [waiting], timeout: 2)
        task.cancel()
        do {
            _ = try await task.value
            XCTFail("Cancellation must escape")
        } catch is CancellationError { }
        let requests = await transport.requests
        XCTAssertEqual(requests.count, 1)
    }

    func testMalformedAuthorizationResponsesAreRejected() async throws {
        for mutation in ["missing", "empty", "oversized", "wrongType"] {
            var body = codeResponse()
            switch mutation {
            case "missing": body.removeValue(forKey: "device_auth_id")
            case "empty": body["user_code"] = " "
            case "oversized": body["device_auth_id"] = String(repeating: "x", count: 4096)
            default: body["user_code"] = 123
            }
            do {
                _ = try await CodexDeviceAuth(transport: AuthTestTransport([response(body)])).begin()
                XCTFail("Malformed authorization must fail")
            } catch CodexDeviceAuthError.invalidResponse { }
        }
    }

    func testMalformedApprovalDoesNotExchange() async throws {
        var body = approval()
        body.removeValue(forKey: "code_challenge")
        let transport = AuthTestTransport([response(body)])
        do {
            _ = try await CodexDeviceAuth(transport: transport).complete(authorization(clock: AuthTestClock(date: Date())))
            XCTFail("Incomplete approval must fail")
        } catch CodexDeviceAuthError.invalidResponse { }
        let requests = await transport.requests
        XCTAssertEqual(requests.count, 1)
    }

    func testRefreshRotationAndFormEncoding() async throws {
        let clock = AuthTestClock()
        let input = syntheticTokens(clock: clock)
        let body = tokenResponse()
        let transport = AuthTestTransport([response(body)])
        let result = try await CodexDeviceAuth(transport: transport, now: { clock.now() }).refresh(input)
        XCTAssertTrue(result.refreshToken == body["refresh_token"] as? String)
        XCTAssertFalse(result.refreshToken == input.refreshToken)
        XCTAssertEqual(result.accountID, "synthetic-account")
        let requests = await transport.requests
        let fields = form(requests[0])
        XCTAssertEqual(fields["grant_type"], "refresh_token")
        XCTAssertTrue(fields["refresh_token"] == input.refreshToken)
        XCTAssertEqual(fields["client_id"], "app_EMoamEEZ73f0CkXaXp7hrann")
    }

    func testRefreshRetainsOmittedRotationAndIdentity() async throws {
        let clock = AuthTestClock()
        var body = tokenResponse()
        body.removeValue(forKey: "refresh_token")
        body.removeValue(forKey: "id_token")
        let input = syntheticTokens(clock: clock)
        let result = try await CodexDeviceAuth(transport: AuthTestTransport([response(body)]), now: { clock.now() }).refresh(input)
        XCTAssertTrue(result.refreshToken == input.refreshToken)
        XCTAssertEqual(result.accountID, input.accountID)
    }

    func testMalformedTokensAndNonFiniteExpirationAreRejected() async throws {
        let clock = AuthTestClock()
        for key in ["access_token", "refresh_token", "id_token", "expires_in"] {
            var body = tokenResponse()
            body[key] = key == "expires_in" ? "Infinity" : ""
            do {
                _ = try await CodexDeviceAuth(transport: AuthTestTransport([response(body)]), now: { clock.now() })
                    .refresh(syntheticTokens(clock: clock))
                XCTFail("Malformed token response must fail")
            } catch CodexDeviceAuthError.invalidResponse { }
        }
        for expiry in [0, -1, 1e300] {
            var body = tokenResponse()
            body["expires_in"] = expiry
            do {
                _ = try await CodexDeviceAuth(transport: AuthTestTransport([response(body)]))
                    .refresh(syntheticTokens(clock: clock))
                XCTFail("Invalid expiry must fail")
            } catch CodexDeviceAuthError.invalidResponse { }
        }
    }

    func testMalformedJWTIdentityAndOversizedTokensAreRejected() async throws {
        let clock = AuthTestClock()
        for idToken in ["not-a-jwt", "e30.@@@@.signature", jwt(account: ""), jwt(account: String(repeating: "a", count: 1024))] {
            var body = tokenResponse()
            body["id_token"] = idToken
            do {
                _ = try await CodexDeviceAuth(transport: AuthTestTransport([response(body)]))
                    .refresh(syntheticTokens(clock: clock))
                XCTFail("Malformed identity must fail")
            } catch CodexDeviceAuthError.invalidResponse { }
        }
        var body = tokenResponse()
        body["access_token"] = String(repeating: "x", count: 20_000)
        do {
            _ = try await CodexDeviceAuth(transport: AuthTestTransport([response(body)]))
                .refresh(syntheticTokens(clock: clock))
            XCTFail("Oversized token must fail")
        } catch CodexDeviceAuthError.invalidResponse { }
    }

    func testRateLimitPreservesRetryDelayWithoutPolling() async throws {
        let transport = AuthTestTransport([HTTPResponse(data: Data(), statusCode: 429, retryAfter: 42)])
        do {
            _ = try await CodexDeviceAuth(transport: transport).complete(authorization(clock: AuthTestClock(date: Date())))
            XCTFail("Rate limit must propagate")
        } catch let error as ProviderError {
            XCTAssertEqual(error, .rateLimited(retryAfter: 42))
        }
        let requests = await transport.requests
        XCTAssertEqual(requests.count, 1)
    }

    func testTransportFailureUsesSafeDescription() async throws {
        do {
            _ = try await CodexDeviceAuth(transport: AuthFailingTransport()).begin()
            XCTFail("Transport must fail")
        } catch let error as ProviderError {
            XCTAssertEqual(error, .transport(ProviderError.transportDescription(for: AuthSyntheticFailure())))
            XCTAssertFalse(error.localizedDescription.contains("synthetic-private-body"))
        }
    }

    func testMalformedResponseDoesNotExposeBodyAndHTTPFailureDoesNotPoll() async throws {
        let transport = AuthTestTransport([
            HTTPResponse(data: Data("synthetic-private-body".utf8), statusCode: 200, retryAfter: nil)
        ])
        do {
            _ = try await CodexDeviceAuth(transport: transport).begin()
            XCTFail("Invalid JSON must fail")
        } catch let error as CodexDeviceAuthError {
            XCTAssertFalse(error.localizedDescription.contains("synthetic-private-body"))
        }
        let denied = AuthTestTransport([response([:], status: 401)])
        do {
            _ = try await CodexDeviceAuth(transport: denied).complete(authorization(clock: AuthTestClock(date: Date())))
            XCTFail("Authorization failure must escape")
        } catch let error as ProviderError {
            XCTAssertEqual(error, .authentication(statusCode: 401))
        }
        let requests = await denied.requests
        XCTAssertEqual(requests.count, 1)
    }

    private func response(_ object: [String: Any], status: Int = 200) -> HTTPResponse {
        HTTPResponse(data: try! JSONSerialization.data(withJSONObject: object), statusCode: status, retryAfter: nil)
    }
    private func codeResponse(interval: Any? = "5") -> [String: Any] {
        var body: [String: Any] = ["device_auth_id": UUID().uuidString, "user_code": "TEST-CODE"]
        body["interval"] = interval
        return body
    }
    private func approval() -> [String: Any] {
        ["authorization_code": "synthetic+code/&=", "code_verifier": String(repeating: "v", count: 43),
         "code_challenge": String(repeating: "c", count: 43)]
    }
    private func tokenResponse() -> [String: Any] {
        ["access_token": UUID().uuidString, "refresh_token": UUID().uuidString,
         "id_token": jwt(account: "synthetic-account"), "expires_in": 3600]
    }
    private func jwt(account: String) -> String {
        let data = try! JSONSerialization.data(withJSONObject: ["https://api.openai.com/auth": ["chatgpt_account_id": account]])
        let payload = data.base64EncodedString().replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
        return "e30.\(payload).synthetic-signature"
    }
    private func authorization(clock: AuthTestClock, expiresIn: TimeInterval = 900) -> DeviceAuthorization {
        DeviceAuthorization(userCode: "TEST-CODE", verificationURL: URL(string: "https://auth.openai.com/codex/device")!,
                            deviceAuthID: UUID().uuidString, interval: 5, expiresAt: clock.now().addingTimeInterval(expiresIn))
    }
    private func syntheticTokens(clock: AuthTestClock) -> CodexMobileTokens {
        CodexMobileTokens(accessToken: UUID().uuidString, refreshToken: UUID().uuidString + "+/&=",
                          accountID: "previous-account", expiresAt: clock.now())
    }
    private func json(_ request: URLRequest) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as? [String: Any])
    }
    private func form(_ request: URLRequest) -> [String: String] {
        let body = String(decoding: request.httpBody ?? Data(), as: UTF8.self).replacingOccurrences(of: "+", with: "%20")
        return Dictionary(uniqueKeysWithValues: (URLComponents(string: "https://example.invalid/?" + body)?.queryItems ?? [])
            .map { ($0.name, $0.value ?? "") })
    }
}

private actor AuthTestTransport: HTTPTransport {
    private var results: [AuthTestResult]
    private(set) var requests: [URLRequest] = []
    init(_ responses: [HTTPResponse]) { results = responses.map { .response($0) } }
    init(results: [AuthTestResult]) { self.results = results }
    func send(_ request: URLRequest) async throws -> HTTPResponse {
        requests.append(request)
        guard !results.isEmpty else { throw URLError(.badServerResponse) }
        switch results.removeFirst() {
        case .response(let response): return response
        case .failure(let code): throw URLError(code)
        }
    }
}

private enum AuthTestResult: Sendable {
    case response(HTTPResponse)
    case failure(URLError.Code)
}

private final class AuthTestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var date: Date
    init(date: Date = Date(timeIntervalSince1970: 1000)) { self.date = date }
    func now() -> Date { lock.withLock { date } }
    func advance(_ duration: Duration) {
        lock.withLock { date.addTimeInterval(Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18) }
    }
}

private struct AuthSyntheticFailure: LocalizedError {
    var errorDescription: String? { "synthetic-private-body" }
}
private struct AuthFailingTransport: HTTPTransport {
    func send(_ request: URLRequest) async throws -> HTTPResponse { throw AuthSyntheticFailure() }
}
