import Foundation

struct ManaCLIOptions: Equatable {
    let provider: ProviderID?
    let json: Bool
    var keyFromStdin = false

    static func parse(_ arguments: [String]) throws -> Self {
        var provider: ProviderID?
        var providerSpecified = false
        var json = false
        var keyFromStdin = false
        var index = 0
        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "--json":
                guard !json else { throw ManaCLIError.invalidArguments("--json was supplied twice") }
                json = true
            case "--key-stdin":
                guard !keyFromStdin else { throw ManaCLIError.invalidArguments("--key-stdin was supplied twice") }
                keyFromStdin = true
            case "--provider":
                index += 1
                guard index < arguments.count else { throw ManaCLIError.invalidArguments("--provider needs codex, opencode-go, or all") }
                guard !providerSpecified else { throw ManaCLIError.invalidArguments("--provider was supplied twice") }
                providerSpecified = true
                provider = try parseProvider(arguments[index])
            default:
                if argument.hasPrefix("--provider=") {
                    guard !providerSpecified else { throw ManaCLIError.invalidArguments("--provider was supplied twice") }
                    providerSpecified = true
                    provider = try parseProvider(String(argument.dropFirst("--provider=".count)))
                } else {
                    throw ManaCLIError.invalidArguments("unknown argument: \(argument)")
                }
            }
            index += 1
        }
        guard !keyFromStdin || provider == .openCodeGo else {
            throw ManaCLIError.invalidArguments("--key-stdin requires --provider opencode-go")
        }
        return Self(provider: provider, json: json, keyFromStdin: keyFromStdin)
    }

    private static func parseProvider(_ value: String) throws -> ProviderID? {
        switch value {
        case "all": return nil
        case "codex": return .codex
        case "opencode-go": return .openCodeGo
        default: throw ManaCLIError.invalidArguments("invalid provider; use codex, opencode-go, or all")
        }
    }
}

enum ManaCLIError: Error {
    case invalidArguments(String)
}

enum ManaCLIResult {
    case success(ProviderSnapshot)
    case failure(ProviderID, ProviderError)

    var provider: ProviderID {
        switch self {
        case .success(let snapshot): return snapshot.provider
        case .failure(let provider, _): return provider
        }
    }

    var failed: Bool {
        if case .failure = self { return true }
        return false
    }
}

enum ManaCLIOutput {
    private static func safeStatus(_ value: String) -> String {
        guard !value.isEmpty, value.count <= 40,
              value.unicodeScalars.allSatisfy({ CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_- ")).contains($0) })
        else { return "unavailable" }
        return value
    }

    static func text(_ results: [ManaCLIResult]) -> String {
        results.map { result in
            switch result {
            case .failure(let provider, let error):
                return "\(provider.displayName): \(error.localizedDescription)"
            case .success(let snapshot):
                var lines = ["\(snapshot.provider.displayName):"]
                if snapshot.isBlocked { lines.append("  Blocked: \(snapshot.blockedReason ?? "rate limit")") }
                if snapshot.displayWindows.isEmpty { lines.append("  No usage windows available") }
                for window in snapshot.displayWindows {
                    let value: String
                    switch window.content {
                    case .percent(let percent): value = String(format: "%.1f%% used", percent)
                    case .unknownPercent: value = "usage unavailable"
                    case .blocked(let reason): value = "blocked: \(safeStatus(reason))"
                    case .missing: continue
                    }
                    let reset = window.resetAt.map { " · resets \(ISO8601DateFormatter().string(from: $0))" } ?? ""
                    lines.append("  \(window.label): \(value)\(reset)")
                }
                return lines.joined(separator: "\n")
            }
        }.joined(separator: "\n") + "\n"
    }

    static func json(_ results: [ManaCLIResult]) throws -> String {
        let records: [[String: Any]] = results.map { result in
            switch result {
            case .failure(let provider, let error):
                return ["provider": provider.rawValue, "error": error.localizedDescription]
            case .success(let snapshot):
                let windows: [[String: Any]] = snapshot.displayWindows.map { window in
                    var item: [String: Any] = ["id": window.id, "label": window.label]
                    switch window.content {
                    case .percent(let value): item["usedPercent"] = value
                    case .unknownPercent: item["status"] = "unknown"
                    case .blocked(let reason): item["status"] = "blocked"; item["reason"] = safeStatus(reason)
                    case .missing: break
                    }
                    if let reset = window.resetAt { item["resetAt"] = ISO8601DateFormatter().string(from: reset) }
                    return item
                }
                return ["provider": snapshot.provider.rawValue, "blocked": snapshot.isBlocked,
                        "windows": windows, "receivedAt": ISO8601DateFormatter().string(from: snapshot.receivedAt)]
            }
        }
        let data = try JSONSerialization.data(withJSONObject: records, options: [.prettyPrinted, .sortedKeys])
        return String(decoding: data, as: UTF8.self) + "\n"
    }
}

@MainActor
enum ManaCLI {
    static let help = """
    Usage: mana [--provider codex|opencode-go|all] [--json]
           mana --provider opencode-go --key-stdin [--json]
           mana --help
           mana --version

    Fetch current provider usage once. Credentials are configured in Mana Settings.
    Mana stores credentials in private local files, not Keychain.
    With both providers selected, one failure does not suppress the other.
    --json prints an array; failed providers have an error instead of usage windows.
    --key-stdin uses one OpenCode Go key from standard input without storing it.
    Exit status: 0 success, 1 provider failure, 2 invalid arguments.
    """

    static func run(_ arguments: [String]) async -> Int32 {
        let args = arguments.first == "--cli" ? Array(arguments.dropFirst()) : arguments
        if args == ["--help"] || args == ["-h"] {
            print(help)
            return 0
        }
        if args == ["--version"] {
            let invoked = CommandLine.arguments[0]
            let located = invoked.contains("/") ? invoked :
                (ProcessInfo.processInfo.environment["PATH"] ?? "")
                    .split(separator: ":").map { "\($0)/\(invoked)" }
                    .first(where: { FileManager.default.isExecutableFile(atPath: $0) }) ?? invoked
            let executable = URL(fileURLWithPath: located).resolvingSymlinksInPath()
            let infoURL = executable.deletingLastPathComponent().deletingLastPathComponent()
                .appendingPathComponent("Info.plist")
            let info = (try? Data(contentsOf: infoURL)).flatMap {
                try? PropertyListSerialization.propertyList(from: $0, format: nil) as? [String: Any]
            }
            let version = info?["CFBundleShortVersionString"] as? String ?? "development"
            print("Mana \(version)")
            return 0
        }
        let options: ManaCLIOptions
        do { options = try ManaCLIOptions.parse(args) }
        catch {
            // Never echo arbitrary arguments: a user may inadvertently pass a credential.
            fputs("Invalid arguments. Run mana --help.\n", stderr)
            return 2
        }

        let stdinKey: String?
        if options.keyFromStdin {
            guard let data = try? FileHandle.standardInput.read(upToCount: 4097),
                  !data.isEmpty, data.count <= 4096,
                  let value = String(data: data, encoding: .utf8),
                  !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                fputs("Expected an OpenCode Go key on stdin (maximum 4096 bytes).\n", stderr)
                return 2
            }
            stdinKey = value.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            stdinKey = nil
        }

        let store = FileCredentialStore()
        let loader = ProviderCredentialLoader(store: store)
        let oauth = CodexOAuthClient(store: store)
        let transport = URLSessionTransport()
        var results: [ManaCLIResult] = []
        for provider in ProviderID.allCases where options.provider == nil || options.provider == provider {
            do {
                let snapshot: ProviderSnapshot
                switch provider {
                case .codex:
                    let data = try await CodexUsageClient(transport: transport).fetch(credentials: oauth.credentials())
                    snapshot = try CodexUsageDecoder.decode(data)
                case .openCodeGo:
                    let credentials = try stdinKey.map { OpenCodeGoCredentials(apiKey: $0) }
                        ?? loader.openCodeGoCredentials()
                    let data = try await OpenCodeGoUsageClient(transport: transport).fetch(credentials: credentials)
                    snapshot = try OpenCodeGoUsageDecoder.decode(data)
                }
                results.append(.success(snapshot))
            } catch {
                let safeError = error as? ProviderError ?? .transport(ProviderError.transportDescription(for: error))
                results.append(.failure(provider, safeError))
            }
        }
        if options.json {
            if let output = try? ManaCLIOutput.json(results) { print(output, terminator: "") }
            else { fputs("Could not format usage.\n", stderr); return 1 }
        } else {
            print(ManaCLIOutput.text(results), terminator: "")
        }
        return results.contains(where: \.failed) ? 1 : 0
    }
}
