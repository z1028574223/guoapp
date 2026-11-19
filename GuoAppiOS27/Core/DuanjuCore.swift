import Foundation

enum CoreError: Error, LocalizedError {
    case emptyResult
    case malformed
    case failed(String, code: String?)

    var errorDescription: String? {
        switch self {
        case .emptyResult: return "本地核心没有返回结果"
        case .malformed: return "无法解析本地核心返回的数据"
        case .failed(let message, _): return message
        }
    }
}

/// Swift bridge to guoapp's Go engine. The engine exposes a single synchronous
/// C function: JSON string in, JSON string out. All heavy work (source scripts,
/// network, caching, downloads, playback routing) stays inside Go.
final class DuanjuCore {
    static let shared = DuanjuCore()

    private let queue = DispatchQueue(label: "com.guoapp.core", qos: .userInitiated)
    private var initialized = false

    private init() {}

    /// Calls the C ABI synchronously. Never call this on the main thread.
    func call(_ payload: [String: Any]) throws -> [String: Any] {
        let input = try JSONSerialization.data(withJSONObject: payload, options: [])
        let cInput = input.withUnsafeBytes { raw -> UnsafeMutablePointer<CChar> in
            let buffer = UnsafeMutableRawPointer.allocate(byteCount: raw.count + 1, alignment: 1)
            if let base = raw.baseAddress {
                buffer.copyMemory(from: base, byteCount: raw.count)
            }
            buffer.storeBytes(of: 0, toByteOffset: raw.count, as: CChar.self)
            return buffer.assumingMemoryBound(to: CChar.self)
        }
        defer { UnsafeMutableRawPointer(cInput).deallocate() }

        guard let output = DuanjuRequest(cInput) else { throw CoreError.emptyResult }
        defer { DuanjuFree(output) }

        let text = String(cString: output)
        guard let data = text.data(using: .utf8),
              let envelope = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { throw CoreError.malformed }

        if let ok = envelope["ok"] as? Bool, !ok {
            throw CoreError.failed(
                envelope["error"] as? String ?? "本地核心处理失败，请重试",
                code: envelope["code"] as? String
            )
        }
        return envelope["data"] as? [String: Any] ?? [:]
    }

    /// Async wrapper that moves the blocking Go call off the main actor.
    func request(_ action: String, _ extra: [String: Any] = [:]) async throws -> [String: Any] {
        var payload = extra
        payload["action"] = action
        return try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    continuation.resume(returning: try self.call(payload))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Must be called once before any other action. Mirrors NativeRepository.initialize().
    func initializeIfNeeded() async throws {
        guard !initialized else { return }
        let fm = FileManager.default
        let support = try fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let root = support.appendingPathComponent("guoapp", isDirectory: true)
        let directory = root.appendingPathComponent("data", isDirectory: true)
        let cache = root.appendingPathComponent("cache", isDirectory: true)
        let downloads = root.appendingPathComponent("downloads", isDirectory: true)
        for url in [directory, cache, downloads] {
            try fm.createDirectory(at: url, withIntermediateDirectories: true)
        }
        _ = try await request("initialize", [
            "directory": directory.path,
            "cache": cache.path,
            "downloads": downloads.path
        ])
        initialized = true
    }
}
