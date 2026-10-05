import Foundation
import ManaCore

struct CodexMobileTokens: Codable, Sendable {
    let accessToken: String
    let refreshToken: String
    let accountID: String
    let expiresAt: Date
}

struct DeviceAuthorization: Sendable {
    let userCode: String
    let verificationURL: URL
    let deviceAuthID: String
    let interval: TimeInterval
    let expiresAt: Date
}

/// In-memory authentication only. The caller owns credential storage and generation checks.
/// Protocol follows codex-rs/login/src/device_code_auth.rs; live iPhone authorization is unverified.
struct CodexDeviceAuth: Sendable {
    private static let clientID = "app_EMoamEEZ73f0CkXaXp7hrann"
    private static let issuer = "https://auth.openai.com"
    private static let lifetime: TimeInterval = 900
    private let transport: any HTTPTransport
    private let now: @Sendable () -> Date
    private let sleep: @Sendable (Duration) async throws -> Void

    init(transport: any HTTPTransport = URLSessionTransport(),
         now: @escaping @Sendable () -> Date = Date.init,
         sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }) {
        self.transport = transport
        self.now = now
        self.sleep = sleep
    }

    func begin() async throws -> DeviceAuthorization {
        let response = try await send(jsonRequest(path: "/api/accounts/deviceauth/usercode", fields: [
            "client_id": Self.clientID
        ]))
        try checkStatus(response)
        let object = try object(response.data)
        let deviceID = try requiredString(object["device_auth_id"], limit: 512)
        let code = try requiredString(object["user_code"] ?? object["usercode"], limit: 128)
        guard let url = URL(string: Self.issuer + "/codex/device") else { throw CodexDeviceAuthError.invalidResponse }
        let date = try currentDate()
        return DeviceAuthorization(userCode: code, verificationURL: url, deviceAuthID: deviceID,
                                   interval: Self.pollInterval(object["interval"]),
                                   expiresAt: date.addingTimeInterval(Self.lifetime))
    }

    func complete(_ authorization: DeviceAuthorization) async throws -> CodexMobileTokens {
        _ = try requiredString(authorization.deviceAuthID, limit: 512)
        _ = try requiredString(authorization.userCode, limit: 128)
        guard authorization.expiresAt.timeIntervalSince1970.isFinite,
              authorization.verificationURL.absoluteString == Self.issuer + "/codex/device",
              authorization.interval.isFinite, authorization.interval > 0 else {
            throw CodexDeviceAuthError.invalidResponse
        }
        let deadline = min(authorization.expiresAt, try currentDate().addingTimeInterval(Self.lifetime))
        // Continuous time also bounds polling if the wall clock moves backwards.
        let clock = ContinuousClock()
        let monotonicDeadline = clock.now.advanced(by: .seconds(Self.lifetime))
        let request = try jsonRequest(path: "/api/accounts/deviceauth/token", fields: [
            "device_auth_id": authorization.deviceAuthID, "user_code": authorization.userCode
        ])
        while true {
            try Task.checkCancellation()
            try checkDeadline(deadline, clock: clock, monotonicDeadline: monotonicDeadline)
            let response: HTTPResponse
            do {
                response = try await send(request)
            } catch {
                guard Self.isInterruptedRequest(error), !Task.isCancelled else { throw error }
                try await waitForNextPoll(authorization, deadline: deadline, clock: clock, monotonicDeadline: monotonicDeadline)
                continue
            }
            try checkDeadline(deadline, clock: clock, monotonicDeadline: monotonicDeadline)
            if response.statusCode == 403 || response.statusCode == 404 {
                try await waitForNextPoll(authorization, deadline: deadline, clock: clock, monotonicDeadline: monotonicDeadline)
                continue
            }
            try checkStatus(response)
            let approval = try object(response.data)
            let code = try requiredString(approval["authorization_code"], limit: 2048)
            let verifier = try requiredString(approval["code_verifier"], limit: 128)
            let challenge = try requiredString(approval["code_challenge"], limit: 128)
            guard Self.isPKCE(verifier), Self.isPKCE(challenge) else { throw CodexDeviceAuthError.invalidResponse }
            let exchangeFields = [
                "grant_type": "authorization_code", "client_id": Self.clientID,
                "redirect_uri": Self.issuer + "/deviceauth/callback", "code": code, "code_verifier": verifier
            ]
            // Keep the approved exchange in memory across interrupted requests.
            // Do not repoll or request a new user code after approval.
            while true {
                try checkDeadline(deadline, clock: clock, monotonicDeadline: monotonicDeadline)
                do {
                    let tokenResponse = try await tokenRequest(exchangeFields)
                    return try tokens(from: tokenResponse, previous: nil)
                } catch {
                    guard Self.isInterruptedRequest(error), !Task.isCancelled else { throw error }
                    try await waitForNextPoll(authorization, deadline: deadline, clock: clock, monotonicDeadline: monotonicDeadline)
                }
            }
        }
    }

    func refresh(_ tokens: CodexMobileTokens) async throws -> CodexMobileTokens {
        _ = try requiredString(tokens.accessToken, limit: 16_384)
        _ = try requiredString(tokens.refreshToken, limit: 16_384)
        _ = try requiredString(tokens.accountID, limit: 512)
        guard tokens.expiresAt.timeIntervalSince1970.isFinite else { throw CodexDeviceAuthError.invalidResponse }
        let response = try await tokenRequest([
            "grant_type": "refresh_token", "client_id": Self.clientID, "refresh_token": tokens.refreshToken
        ])
        return try self.tokens(from: response, previous: tokens)
    }

    private func tokenRequest(_ fields: [String: String]) async throws -> Data {
        var request = try request(path: "/oauth/token", contentType: "application/x-www-form-urlencoded")
        // Encode each form component, including '+' and '&'; URL query encoding alone is insufficient.
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        let body = try fields.sorted { $0.key < $1.key }.map { key, value in
            guard let name = key.addingPercentEncoding(withAllowedCharacters: allowed),
                  let encoded = value.addingPercentEncoding(withAllowedCharacters: allowed) else {
                throw CodexDeviceAuthError.invalidResponse
            }
            return name + "=" + encoded
        }.joined(separator: "&")
        request.httpBody = Data(body.utf8)
        let response = try await send(request)
        try checkStatus(response)
        return response.data
    }

    private func tokens(from data: Data, previous: CodexMobileTokens?) throws -> CodexMobileTokens {
        let object = try object(data)
        let access = try requiredString(object["access_token"], limit: 16_384)
        let refresh = try requiredString(object["refresh_token"] ?? previous?.refreshToken, limit: 16_384)
        let account: String
        if let idToken = object["id_token"] {
            account = try Self.accountID(from: requiredString(idToken, limit: 16_384))
        } else {
            account = try requiredString(previous?.accountID, limit: 512)
        }
        let expiry: TimeInterval
        if let value = object["expires_in"] {
            guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() else {
                throw CodexDeviceAuthError.invalidResponse
            }
            expiry = number.doubleValue
        } else {
            expiry = 3600
        }
        guard expiry.isFinite, expiry > 0, expiry <= 31_536_000 else { throw CodexDeviceAuthError.invalidResponse }
        let expiresAt = try currentDate().addingTimeInterval(expiry)
        guard expiresAt.timeIntervalSince1970.isFinite else { throw CodexDeviceAuthError.invalidResponse }
        return CodexMobileTokens(accessToken: access, refreshToken: refresh, accountID: account, expiresAt: expiresAt)
    }

    private func request(path: String, contentType: String) throws -> URLRequest {
        guard let url = URL(string: Self.issuer + path) else { throw CodexDeviceAuthError.invalidResponse }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        request.httpMethod = "POST"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    private func jsonRequest(path: String, fields: [String: String]) throws -> URLRequest {
        var request = try request(path: path, contentType: "application/json")
        do { request.httpBody = try JSONSerialization.data(withJSONObject: fields) }
        catch { throw CodexDeviceAuthError.invalidResponse }
        return request
    }

    private func send(_ request: URLRequest) async throws -> HTTPResponse {
        try Task.checkCancellation()
        do {
            let response = try await transport.send(request)
            try Task.checkCancellation()
            return response
        } catch {
            if error is CancellationError || Task.isCancelled || (error as? URLError)?.code == .cancelled {
                throw CancellationError()
            }
            // Never forward transport descriptions or error payloads supplied by a server.
            throw ProviderError.transport(ProviderError.transportDescription(for: error))
        }
    }

    private func checkStatus(_ response: HTTPResponse) throws {
        switch response.statusCode {
        case 200..<300: return
        case 429:
            let delay = response.retryAfter.flatMap { $0.isFinite && $0 >= 0 && $0 < Double(Int.max) ? $0 : nil }
            throw ProviderError.rateLimited(retryAfter: delay)
        case 401, 403: throw ProviderError.authentication(statusCode: response.statusCode)
        default: throw ProviderError.response(statusCode: response.statusCode)
        }
    }

    private func checkDeadline(_ deadline: Date, clock: ContinuousClock, monotonicDeadline: ContinuousClock.Instant) throws {
        guard try currentDate() < deadline, clock.now < monotonicDeadline else { throw CodexDeviceAuthError.expired }
    }

    private func waitForNextPoll(_ authorization: DeviceAuthorization, deadline: Date,
                                 clock: ContinuousClock, monotonicDeadline: ContinuousClock.Instant) async throws {
        try Task.checkCancellation()
        try checkDeadline(deadline, clock: clock, monotonicDeadline: monotonicDeadline)
        let remaining = deadline.timeIntervalSince(try currentDate())
        let delay = min(Duration.seconds(min(max(1, authorization.interval), remaining)), clock.now.duration(to: monotonicDeadline))
        try await sleep(delay)
        try Task.checkCancellation()
    }

    private static func isInterruptedRequest(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        if case ProviderError.transport = error { return true }
        return false
    }

    private func currentDate() throws -> Date {
        let date = now()
        guard date.timeIntervalSince1970.isFinite else { throw CodexDeviceAuthError.invalidResponse }
        return date
    }

    private func object(_ data: Data) throws -> [String: Any] {
        try Self.decodeObject(data)
    }

    private static func decodeObject(_ data: Data) throws -> [String: Any] {
        guard !data.isEmpty, data.count <= 131_072,
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw CodexDeviceAuthError.invalidResponse
        }
        return object
    }

    private func requiredString(_ value: Any?, limit: Int) throws -> String {
        try Self.validString(value, limit: limit)
    }

    private static func validString(_ value: Any?, limit: Int) throws -> String {
        guard let string = value as? String, !string.isEmpty, string.utf8.count <= limit,
              string.unicodeScalars.allSatisfy({ $0.value > 32 && $0.value < 127 }) else {
            throw CodexDeviceAuthError.invalidResponse
        }
        return string
    }

    private static func isPKCE(_ value: String) -> Bool {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        return (43...128).contains(value.utf8.count) && value.unicodeScalars.allSatisfy { allowed.contains($0) }
    }

    private static func pollInterval(_ value: Any?) -> TimeInterval {
        let number: Double?
        if let string = value as? String, string.utf8.count <= 32 {
            number = Double(string.trimmingCharacters(in: .whitespacesAndNewlines))
        } else if let value = value as? NSNumber, CFGetTypeID(value) != CFBooleanGetTypeID() {
            number = value.doubleValue
        } else {
            number = nil
        }
        guard let number, number.isFinite, number > 0 else { return 5 }
        // Never poll faster than the issuer requests. An interval beyond the code's
        // lifetime waits to expiry without another request.
        return min(Self.lifetime, max(1, number))
    }

    private static func accountID(from token: String) throws -> String {
        let segments = token.split(separator: ".", omittingEmptySubsequences: false)
        guard segments.count == 3, segments.allSatisfy({ !$0.isEmpty }) else { throw CodexDeviceAuthError.invalidResponse }
        let payload = String(segments[1])
        let alphabet = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_")
        guard payload.unicodeScalars.allSatisfy({ alphabet.contains($0) }), payload.utf8.count % 4 != 1 else {
            throw CodexDeviceAuthError.invalidResponse
        }
        let base64 = payload.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
            + String(repeating: "=", count: (4 - payload.utf8.count % 4) % 4)
        guard let data = Data(base64Encoded: base64) else { throw CodexDeviceAuthError.invalidResponse }
        // Extract routing metadata, not JWT signature verification. Tokens came from the issuer over HTTPS.
        let object = try decodeObject(data)
        guard let account = try findAccountID(object, depth: 0) else { throw CodexDeviceAuthError.invalidResponse }
        return account
    }

    private static func findAccountID(_ object: [String: Any], depth: Int) throws -> String? {
        guard depth <= 8 else { throw CodexDeviceAuthError.invalidResponse }
        if let value = object["chatgpt_account_id"] { return try validString(value, limit: 512) }
        var found: String?
        for value in object.values {
            if let nested = value as? [String: Any], let account = try findAccountID(nested, depth: depth + 1) {
                guard found == nil || found == account else { throw CodexDeviceAuthError.invalidResponse }
                found = account
            }
        }
        return found
    }
}

enum CodexDeviceAuthError: Error, LocalizedError, Sendable {
    case invalidResponse
    case expired

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return String(localized: "OpenAI returned an invalid sign-in response.")
        case .expired: return String(localized: "OpenAI sign-in expired. Start sign-in again.")
        }
    }
}
