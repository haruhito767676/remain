import Foundation
import Darwin

public enum IPCRequest: Codable, Sendable {
    case hook(HookPayload)
    case status
    /// Human-readable dump of every tracked session, for debugging.
    case sessions
    /// `nil` minutes means indefinitely.
    case keepAwake(minutes: Int?)
    case release
}

public struct IPCResponse: Codable, Sendable {
    public var ok: Bool
    public var message: String?
    public var snapshot: WakeSnapshot?

    public init(ok: Bool, message: String? = nil, snapshot: WakeSnapshot? = nil) {
        self.ok = ok
        self.message = message
        self.snapshot = snapshot
    }
}

public enum IPCError: Error, CustomStringConvertible {
    case system(String, Int32)
    case pathTooLong
    case malformed

    public var description: String {
        switch self {
        case .system(let what, let code): "\(what): \(String(cString: strerror(code)))"
        case .pathTooLong: "socket path is too long"
        case .malformed: "malformed message"
        }
    }
}

extension WakeCoordinator {
    /// Shared request handling for the app's IPC server.
    public func handle(_ request: IPCRequest) -> IPCResponse {
        switch request {
        case .hook(let payload):
            if let event = payload.agentEvent { receive(event) }
        case .status:
            break
        case .sessions:
            return IPCResponse(ok: true, message: describeSessions(), snapshot: snapshot)
        case .keepAwake(let minutes):
            setManual(minutes: minutes)
        case .release:
            setManual(.off)
        }
        return IPCResponse(ok: true, snapshot: snapshot)
    }
}

// MARK: - Low-level socket helpers

private func makeAddress(_ path: String) throws -> sockaddr_un {
    var addr = sockaddr_un()
    addr.sun_family = sa_family_t(AF_UNIX)
    let bytes = Array(path.utf8CString)
    guard bytes.count <= MemoryLayout.size(ofValue: addr.sun_path) else { throw IPCError.pathTooLong }
    withUnsafeMutableBytes(of: &addr.sun_path) { raw in
        for (i, byte) in bytes.enumerated() { raw[i] = UInt8(bitPattern: byte) }
    }
    return addr
}

private func configure(_ fd: Int32, timeout: Int) {
    var tv = timeval(tv_sec: timeout, tv_usec: 0)
    setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
    setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
    var one: Int32 = 1
    setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &one, socklen_t(MemoryLayout<Int32>.size))
}

private func readLine(_ fd: Int32, limit: Int = 1 << 20) -> Data? {
    var data = Data()
    var buffer = [UInt8](repeating: 0, count: 4096)
    while data.count < limit {
        let n = read(fd, &buffer, buffer.count)
        if n <= 0 { break }
        data.append(contentsOf: buffer[0..<n])
        if buffer[0..<n].contains(UInt8(ascii: "\n")) { break }
    }
    return data.isEmpty ? nil : data
}

private func writeAll(_ fd: Int32, _ data: Data) {
    var bytes = data
    bytes.append(UInt8(ascii: "\n"))
    bytes.withUnsafeBytes { raw in
        var offset = 0
        while offset < raw.count {
            let n = write(fd, raw.baseAddress!.advanced(by: offset), raw.count - offset)
            if n <= 0 { return }
            offset += n
        }
    }
}

// MARK: - Server (runs inside the app)

/// Newline-delimited JSON over a Unix domain socket, readable only by the current user.
public final class IPCServer: @unchecked Sendable {
    private let path: String
    private var listenFD: Int32 = -1

    public init(path: String = RemainPaths.socketPath) {
        self.path = path
    }

    public func start(handler: @escaping @Sendable (IPCRequest) async -> IPCResponse) throws {
        try FileManager.default.createDirectory(
            atPath: (path as NSString).deletingLastPathComponent,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        unlink(path)

        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw IPCError.system("socket", errno) }

        var addr = try makeAddress(path)
        let bound = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard bound == 0 else { close(fd); throw IPCError.system("bind", errno) }
        chmod(path, 0o600)
        guard listen(fd, 16) == 0 else { close(fd); throw IPCError.system("listen", errno) }
        listenFD = fd

        Thread.detachNewThread {
            while true {
                let client = accept(fd, nil, nil)
                if client < 0 { return }
                configure(client, timeout: 1)
                guard let line = readLine(client),
                      let request = try? JSONDecoder().decode(IPCRequest.self, from: line) else {
                    close(client)
                    continue
                }
                Task.detached {
                    let response = await handler(request)
                    if let data = try? JSONEncoder().encode(response) { writeAll(client, data) }
                    close(client)
                }
            }
        }
    }

    public func stop() {
        if listenFD >= 0 { close(listenFD); listenFD = -1 }
        unlink(path)
    }
}

// MARK: - Client (used by the CLI)

public enum IPCClient {
    public static func send(_ request: IPCRequest, socketPath: String = RemainPaths.socketPath) throws -> IPCResponse {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw IPCError.system("socket", errno) }
        defer { close(fd) }
        configure(fd, timeout: 1)

        var addr = try makeAddress(socketPath)
        let connected = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard connected == 0 else { throw IPCError.system("connect", errno) }

        writeAll(fd, try JSONEncoder().encode(request))
        guard let line = readLine(fd) else { throw IPCError.malformed }
        return try JSONDecoder().decode(IPCResponse.self, from: line)
    }
}
