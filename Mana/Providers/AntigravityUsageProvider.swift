import Foundation

/// Reads Antigravity's own coding-plan quota through its installed first-party CLI.
/// Never reads or copies the CLI's credentials. Its reset_time currently slides on each poll,
/// so the app deliberately omits reset dates until their semantics are verified.
struct AntigravityUsageProvider: UsageProviding {
    let provider: ProviderID = .antigravity
    let executablePath: @Sendable () -> String
    let runner: @Sendable (String) async throws -> Data

    init(executablePath: @escaping @Sendable () -> String,
         runner: @escaping @Sendable (String) async throws -> Data = AntigravityUsageProvider.runCLI) {
        self.executablePath = executablePath
        self.runner = runner
    }

    func fetchSnapshot() async throws -> ProviderSnapshot {
        let data = try await runner(executablePath())
        return try Self.decode(data)
    }

    static func decode(_ data: Data, now: Date = Date()) throws -> ProviderSnapshot {
        struct Envelope: Decodable {
            let status: String
            let command: Command?
            struct Command: Decodable {
                let name: String
                let data: Payload?
            }
            struct Payload: Decodable {
                let groups: [Group]
            }
            struct Group: Decodable {
                let name: String
                let buckets: [Bucket]
            }
            struct Bucket: Decodable {
                let id: String
                let name: String
                let remaining_fraction: Double
            }
        }
        guard let envelope = try? JSONDecoder().decode(Envelope.self, from: data),
              envelope.status == "SUCCESS", envelope.command?.name == "usage",
              let groups = envelope.command?.data?.groups, !groups.isEmpty else {
            throw ProviderError.malformedResponse
        }
        var windows: [UsageWindow] = []
        var seen = Set<String>()
        for group in groups {
            guard ["Gemini Models", "Claude and GPT models"].contains(group.name),
                  !group.buckets.isEmpty else { throw ProviderError.malformedResponse }
            for bucket in group.buckets {
                guard ["gemini-weekly", "gemini-5h", "3p-weekly", "3p-5h"].contains(bucket.id),
                      seen.insert(bucket.id).inserted,
                      bucket.remaining_fraction.isFinite,
                      (0...1).contains(bucket.remaining_fraction) else {
                    throw ProviderError.malformedResponse
                }
                let groupName = group.name == "Gemini Models" ? "Gemini" : "Claude/GPT (Antigravity)"
                let interval = bucket.id.hasSuffix("weekly") ? "Weekly" : "5h"
                windows.append(UsageWindow(id: bucket.id, label: "\(groupName) \(interval)",
                                           content: .percent((1 - bucket.remaining_fraction) * 100),
                                           resetAt: nil, resetText: nil))
            }
        }
        guard !windows.isEmpty else { throw ProviderError.malformedResponse }
        return ProviderSnapshot(provider: .antigravity, windows: windows,
                                isBlocked: false, blockedReason: nil, receivedAt: now)
    }

    static func runCLI(_ path: String) async throws -> Data {
        guard path.hasPrefix("/"), FileManager.default.isExecutableFile(atPath: path) else {
            throw ProviderError.missingCredential(provider: .antigravity, field: "agy executable path")
        }
        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: path)
            process.arguments = ["--print", "/usage", "--output-format", "json"]
            process.currentDirectoryURL = FileManager.default.homeDirectoryForCurrentUser
            let output = Pipe()
            process.standardOutput = output
            process.standardError = FileHandle.nullDevice
            process.standardInput = FileHandle.nullDevice
            let gate = AntigravityResultGate(continuation)
            do {
                try process.run()
            } catch {
                gate.finish(.failure(ProviderError.transport(String(localized: "Could not launch agy."))))
                return
            }
            DispatchQueue.global(qos: .utility).async {
                var data = Data()
                while true {
                    let chunk = output.fileHandleForReading.readData(ofLength: 8192)
                    if chunk.isEmpty { break }
                    data.append(chunk)
                    if data.count > 65_536 {
                        process.terminate()
                        gate.finish(.failure(ProviderError.malformedResponse))
                        return
                    }
                }
                process.waitUntilExit()
                if process.terminationStatus == 0 {
                    gate.finish(.success(data))
                } else {
                    gate.finish(.failure(ProviderError.transport(String(localized: "agy could not fetch usage. Check its sign-in in a terminal."))))
                }
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + 20) {
                if gate.isPending {
                    if process.isRunning { process.terminate() }
                    gate.finish(.failure(ProviderError.transport(String(localized: "agy usage timed out."))))
                }
            }
        }
    }
}

private final class AntigravityResultGate: @unchecked Sendable {
    private let lock = NSLock()
    private var completed = false
    private let continuation: CheckedContinuation<Data, Error>

    init(_ continuation: CheckedContinuation<Data, Error>) { self.continuation = continuation }

    var isPending: Bool {
        lock.lock()
        defer { lock.unlock() }
        return !completed
    }

    func finish(_ result: Result<Data, Error>) {
        lock.lock()
        guard !completed else { lock.unlock(); return }
        completed = true
        lock.unlock()
        continuation.resume(with: result)
    }
}
