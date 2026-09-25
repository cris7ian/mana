import AppKit
import CryptoKit
import Darwin
import Foundation
import Security

struct CodexOAuthTokens: Codable, Sendable {
    let accessToken: String
    let refreshToken: String
    let accountID: String
    let expiresAt: Date
}

@MainActor
final class CodexOAuthClient {
    // Public Codex CLI OAuth client ID; native PKCE clients do not use a client secret.
    static let clientID = "app_EMoamEEZ73f0CkXaXp7hrann"
    static let issuer = URL(string: "https://auth.openai.com")!
    static let credentialAccount = "openai-codex-oauth"
    private let store: any ProviderCredentialStoring
    private let now: () -> Date
    private var credentialGeneration = 0

    init(store: any ProviderCredentialStoring, now: @escaping () -> Date = Date.init) {
        self.store = store
        self.now = now
    }

    var isSignedIn: Bool { (try? loadTokens()) != nil }

    func signIn() async throws {
        let verifier = try Self.randomURLSafeString(byteCount: 32)
        let challenge = Self.base64URL(Data(SHA256.hash(data: Data(verifier.utf8))))
        let state = try Self.randomURLSafeString(byteCount: 32)
        let listener = try LoopbackOAuthListener()
        defer { listener.close() }

        var components = URLComponents(url: Self.issuer.appending(path: "/oauth/authorize"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: Self.clientID),
            URLQueryItem(name: "redirect_uri", value: listener.redirectURI.absoluteString),
            URLQueryItem(name: "scope", value: "openid profile email offline_access api.connectors.read api.connectors.invoke"),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "id_token_add_organizations", value: "true"),
            URLQueryItem(name: "codex_cli_simplified_flow", value: "true"),
            URLQueryItem(name: "originator", value: "mana_macos")
        ]
        guard let authorizationURL = components.url, NSWorkspace.shared.open(authorizationURL) else {
            throw CodexOAuthError.browserUnavailable
        }

        let callback = try await Task.detached(priority: .userInitiated) {
            try listener.waitForCallback()
        }.value
        guard callback.state == state else { throw CodexOAuthError.invalidState }
        if let error = callback.error, !error.isEmpty { throw CodexOAuthError.authorizationDenied }
        guard let code = callback.code, !code.isEmpty else { throw CodexOAuthError.missingAuthorizationCode }

        let tokens = try await exchangeCode(code, verifier: verifier, redirectURI: listener.redirectURI)
        try save(tokens)
    }

    func credentials() async throws -> CodexCredentials {
        let generation = credentialGeneration
        var tokens = try loadTokens()
        if tokens.expiresAt <= now().addingTimeInterval(60) {
            tokens = try await refresh(tokens)
            guard generation == credentialGeneration else { throw ProviderError.cancelled }
            try save(tokens)
        }
        return CodexCredentials(accessToken: tokens.accessToken, accountID: tokens.accountID)
    }

    func signOut() throws {
        credentialGeneration += 1
        try store.remove(Self.credentialAccount)
    }

    private func loadTokens() throws -> CodexOAuthTokens {
        guard let data = try store.read(Self.credentialAccount) else {
            throw ProviderError.missingCredential(provider: .codex, field: "OpenAI sign-in")
        }
        do { return try JSONDecoder().decode(CodexOAuthTokens.self, from: data) }
        catch { throw ProviderError.missingCredential(provider: .codex, field: "OpenAI sign-in") }
    }

    private func save(_ tokens: CodexOAuthTokens) throws {
        try store.write(JSONEncoder().encode(tokens), account: Self.credentialAccount)
    }

    private func exchangeCode(_ code: String, verifier: String, redirectURI: URL) async throws -> CodexOAuthTokens {
        let data = try await tokenRequest([
            "grant_type": "authorization_code",
            "client_id": Self.clientID,
            "code": code,
            "redirect_uri": redirectURI.absoluteString,
            "code_verifier": verifier
        ])
        let response = try JSONDecoder().decode(OAuthTokenResponse.self, from: data)
        guard let refreshToken = response.refreshToken,
              let accountID = Self.accountID(from: response.idToken) else {
            throw CodexOAuthError.invalidTokenResponse
        }
        return CodexOAuthTokens(
            accessToken: response.accessToken,
            refreshToken: refreshToken,
            accountID: accountID,
            expiresAt: now().addingTimeInterval(TimeInterval(response.expiresIn ?? 3600))
        )
    }

    private func refresh(_ tokens: CodexOAuthTokens) async throws -> CodexOAuthTokens {
        let data = try await tokenRequest([
            "grant_type": "refresh_token",
            "client_id": Self.clientID,
            "refresh_token": tokens.refreshToken
        ])
        let response = try JSONDecoder().decode(OAuthTokenResponse.self, from: data)
        return CodexOAuthTokens(
            accessToken: response.accessToken,
            refreshToken: response.refreshToken ?? tokens.refreshToken,
            accountID: Self.accountID(from: response.idToken) ?? tokens.accountID,
            expiresAt: now().addingTimeInterval(TimeInterval(response.expiresIn ?? 3600))
        )
    }

    private func tokenRequest(_ fields: [String: String]) async throws -> Data {
        var request = URLRequest(url: Self.issuer.appending(path: "/oauth/token"), timeoutInterval: 15)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        var components = URLComponents()
        components.queryItems = fields.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        request.httpBody = components.percentEncodedQuery?.data(using: .utf8)
        let (data, response): (Data, URLResponse)
        do { (data, response) = try await URLSession.shared.data(for: request) }
        catch { throw ProviderError.transport(ProviderError.transportDescription(for: error)) }
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw CodexOAuthError.tokenExchangeFailed
        }
        return data
    }

    private static func accountID(from idToken: String?) -> String? {
        guard let idToken,
              let segment = idToken.split(separator: ".").dropFirst().first,
              let payload = Data(base64Encoded: base64URLPadding(String(segment)), options: .ignoreUnknownCharacters),
              let object = try? JSONSerialization.jsonObject(with: payload) as? [String: Any] else { return nil }
        return findAccountID(in: object)
    }

    private static func findAccountID(in object: [String: Any]) -> String? {
        if let value = object["chatgpt_account_id"] as? String, !value.isEmpty { return value }
        for value in object.values {
            if let nested = value as? [String: Any], let accountID = findAccountID(in: nested) { return accountID }
        }
        return nil
    }

    private static func randomURLSafeString(byteCount: Int) throws -> String {
        var bytes = [UInt8](repeating: 0, count: byteCount)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
            throw CodexOAuthError.secureRandomFailed
        }
        return base64URL(Data(bytes))
    }

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString().replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }

    private static func base64URLPadding(_ value: String) -> String {
        value + String(repeating: "=", count: (4 - value.count % 4) % 4)
    }
}

private struct OAuthTokenResponse: Decodable {
    let accessToken: String
    let refreshToken: String?
    let idToken: String?
    let expiresIn: Int?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case idToken = "id_token"
        case expiresIn = "expires_in"
    }
}

private struct OAuthCallback: Sendable {
    let code: String?
    let state: String?
    let error: String?
}

private enum CodexOAuthError: Error, LocalizedError {
    case browserUnavailable, callbackTimedOut, invalidCallback, invalidState, secureRandomFailed
    case authorizationDenied, missingAuthorizationCode, invalidTokenResponse, tokenExchangeFailed

    var errorDescription: String? {
        switch self {
        case .browserUnavailable: return String(localized: "Could not open the OpenAI sign-in page.")
        case .callbackTimedOut: return String(localized: "OpenAI sign-in timed out. Try again.")
        case .invalidCallback, .invalidState: return String(localized: "OpenAI sign-in could not be verified. Try again.")
        case .secureRandomFailed: return String(localized: "Could not securely start OpenAI sign-in.")
        case .authorizationDenied: return String(localized: "OpenAI sign-in was cancelled or denied.")
        case .missingAuthorizationCode, .invalidTokenResponse: return String(localized: "OpenAI returned an invalid sign-in response.")
        case .tokenExchangeFailed: return String(localized: "OpenAI sign-in failed while exchanging credentials.")
        }
    }
}

private final class LoopbackOAuthListener: @unchecked Sendable {
    let redirectURI: URL
    private let descriptor: Int32

    init() throws {
        var selected: (Int32, UInt16)?
        for port in [UInt16(1455), 1457] {
            let fd = socket(AF_INET, SOCK_STREAM, 0)
            guard fd >= 0 else { continue }
            var address = sockaddr_in()
            address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
            address.sin_family = sa_family_t(AF_INET)
            address.sin_port = in_port_t(port).bigEndian
            address.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))
            let bindStatus = withUnsafePointer(to: &address) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
            if bindStatus == 0, listen(fd, 1) == 0 {
                selected = (fd, port)
                break
            }
            Darwin.close(fd)
        }
        guard let (fd, port) = selected,
              let url = URL(string: "http://localhost:\(port)/auth/callback") else {
            throw CodexOAuthError.invalidCallback
        }
        descriptor = fd
        redirectURI = url
    }

    func waitForCallback() throws -> OAuthCallback {

        var readiness = pollfd(fd: descriptor, events: Int16(POLLIN), revents: 0)
        guard poll(&readiness, 1, 300_000) > 0 else { throw CodexOAuthError.callbackTimedOut }
        let client = accept(descriptor, nil, nil)
        guard client >= 0 else { throw CodexOAuthError.invalidCallback }
        defer { Darwin.close(client) }
        var buffer = [UInt8](repeating: 0, count: 8192)
        let count = recv(client, &buffer, buffer.count - 1, 0)
        guard count > 0,
              let requestLine = String(bytes: buffer[..<count], encoding: .utf8)?.components(separatedBy: "\r\n").first,
              requestLine.hasPrefix("GET "),
              let path = requestLine.split(separator: " ").dropFirst().first,
              let callbackURL = URL(string: "http://localhost\(path)"),
              callbackURL.path == "/auth/callback",
              let items = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?.queryItems else {
            respond(client, success: false)
            throw CodexOAuthError.invalidCallback
        }
        respond(client, success: true)
        return OAuthCallback(
            code: items.first(where: { $0.name == "code" })?.value,
            state: items.first(where: { $0.name == "state" })?.value,
            error: items.first(where: { $0.name == "error" })?.value
        )
    }

    func close() { Darwin.close(descriptor) }

    private func respond(_ client: Int32, success: Bool) {
        let body = success
            ? "<!doctype html><title>Mana</title><p>\(String(localized: "OpenAI sign-in complete. You can return to Mana."))</p>"
            : "<!doctype html><title>Mana</title><p>\(String(localized: "Sign-in failed. Return to Mana and try again."))</p>"
        let response = "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nConnection: close\r\nContent-Length: \(body.utf8.count)\r\n\r\n\(body)"
        _ = response.withCString { send(client, $0, response.utf8.count, 0) }
    }
}
