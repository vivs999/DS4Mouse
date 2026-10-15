import DS4Core
import Darwin
import Foundation

public enum LocalConnectionError: Error, LocalizedError, Sendable {
  case notRunning
  case failed(String)
  public var errorDescription: String? {
    switch self {
    case .notRunning: "DS4Mouse is not running."
    case .failed(let message): "Local command failed; its outcome may be uncertain. \(message)"
    }
  }
}

public enum LocalSocket {
  public static func directory() throws -> URL {
    var buffer = [CChar](repeating: 0, count: 4096)
    guard confstr(_CS_DARWIN_USER_TEMP_DIR, &buffer, buffer.count) > 0 else {
      throw AppError("Cannot locate the private user temporary directory.")
    }
    let base = URL(fileURLWithPath: String(cString: buffer)).appendingPathComponent(
      "ds4mouse", isDirectory: true)
    var info = stat()
    if lstat(base.path, &info) == 0 {
      guard info.st_uid == getuid(), info.st_mode & S_IFMT == S_IFDIR,
        info.st_mode & 0o077 == 0
      else { throw AppError("Unsafe permissions on the DS4Mouse socket directory.") }
    } else {
      guard errno == ENOENT else { throw AppError("Cannot inspect the socket directory.") }
      do {
        try FileManager.default.createDirectory(
          at: base, withIntermediateDirectories: false,
          attributes: [.posixPermissions: 0o700])
      } catch {
        guard lstat(base.path, &info) == 0, info.st_uid == getuid(),
          info.st_mode & S_IFMT == S_IFDIR, info.st_mode & 0o077 == 0
        else { throw error }
      }
    }
    return base
  }
  static func address(_ path: String) throws -> sockaddr_un {
    var result = sockaddr_un()
    let bytes = Array(path.utf8) + [0]
    guard bytes.count <= MemoryLayout.size(ofValue: result.sun_path) else {
      throw AppError("The local socket path is too long.")
    }
    result.sun_family = sa_family_t(AF_UNIX)
    result.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
    withUnsafeMutableBytes(of: &result.sun_path) { destination in
      destination.copyBytes(from: bytes)
    }
    return result
  }
  static func configure(_ fd: Int32) {
    var yes: Int32 = 1
    setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &yes, socklen_t(MemoryLayout.size(ofValue: yes)))
    var timeout = timeval(tv_sec: 3, tv_usec: 0)
    setsockopt(
      fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout.size(ofValue: timeout)))
    setsockopt(
      fd, SOL_SOCKET, SO_SNDTIMEO, &timeout, socklen_t(MemoryLayout.size(ofValue: timeout)))
    _ = fcntl(fd, F_SETFD, FD_CLOEXEC)
  }
  static func readLine(_ fd: Int32, deadline: Double = ProcessInfo.processInfo.systemUptime + 3)
    throws -> Data
  {
    var result = Data()
    var buffer = [UInt8](repeating: 0, count: 4096)
    while result.count <= 65536 {
      try applyDeadline(fd, option: SO_RCVTIMEO, deadline: deadline)
      let count = recv(fd, &buffer, buffer.count, 0)
      if count < 0 && errno == EINTR { continue }
      guard count > 0 else { throw AppError("Local connection closed or timed out.") }
      result.append(contentsOf: buffer.prefix(count))
      if let newline = result.firstIndex(of: 10) {
        guard newline <= 65536 else { break }
        return result.prefix(upTo: newline)
      }
    }
    throw AppError("Local request exceeds 64 KiB.")
  }
  static func write<T: Encodable>(_ value: T, to fd: Int32) throws {
    var data = try JSONEncoder().encode(value)
    guard data.count <= 65536 else { throw AppError("Local response exceeds 64 KiB.") }
    data.append(10)
    let deadline = ProcessInfo.processInfo.systemUptime + 3
    try data.withUnsafeBytes { bytes in
      var offset = 0
      while offset < bytes.count {
        try applyDeadline(fd, option: SO_SNDTIMEO, deadline: deadline)
        let sent = send(fd, bytes.baseAddress!.advanced(by: offset), bytes.count - offset, 0)
        if sent < 0 && errno == EINTR { continue }
        guard sent > 0 else { throw AppError("Could not write to the local connection.") }
        offset += sent
      }
    }
  }
  private static func applyDeadline(_ fd: Int32, option: Int32, deadline: Double) throws {
    let remaining = deadline - ProcessInfo.processInfo.systemUptime
    guard remaining > 0 else { throw AppError("Local command deadline exceeded.") }
    var interval = timeval(
      tv_sec: Int(remaining), tv_usec: Int32((remaining - floor(remaining)) * 1_000_000))
    guard
      setsockopt(fd, SOL_SOCKET, option, &interval, socklen_t(MemoryLayout.size(ofValue: interval)))
        == 0
    else {
      throw AppError("Could not set the local command deadline.")
    }
  }
  static func verifyPeer(_ fd: Int32) throws {
    var uid: uid_t = 0
    var gid: gid_t = 0
    guard getpeereid(fd, &uid, &gid) == 0, uid == getuid() else {
      throw AppError("The local connection belongs to a different user.")
    }
  }
  public static func request(_ request: ControlRequest, in directoryURL: URL? = nil) throws
    -> ControlResponse
  {
    let fd = socket(AF_UNIX, SOCK_STREAM, 0)
    guard fd >= 0 else { throw AppError("Cannot create a local socket.") }
    defer { close(fd) }
    configure(fd)
    let base = try directoryURL ?? directory()
    var address = try address(base.appendingPathComponent("control.sock").path)
    let connected = withUnsafePointer(to: &address) {
      $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
        connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
      }
    }
    guard connected == 0 else {
      if errno == ENOENT || errno == ECONNREFUSED { throw LocalConnectionError.notRunning }
      throw LocalConnectionError.failed("Could not connect (\(errno)).")
    }
    do {
      try verifyPeer(fd)
      try write(request, to: fd)
      let result = try JSONDecoder().decode(ControlResponse.self, from: readLine(fd))
      guard result.protocolVersion == 1 else {
        throw AppError("The app and CLI protocol versions do not match.")
      }
      return result
    } catch { throw LocalConnectionError.failed(error.localizedDescription) }
  }
}

// Listener and client state are confined to queue. The handler dispatches app work to MainActor.
public final class LocalServer: @unchecked Sendable {
  public typealias Handler =
    @Sendable (ControlRequest, @escaping @Sendable (ControlResponse) -> Void) -> Void
  private let queue = DispatchQueue(label: "DS4Mouse.control")
  private let source: DispatchSourceRead
  private let lock: Int32
  private let path: String
  private var clients: Set<Int32> = []
  private var stopped = false

  public init(directory directoryURL: URL? = nil, handler: @escaping Handler) throws {
    let directory = try directoryURL ?? LocalSocket.directory()
    path = directory.appendingPathComponent("control.sock").path
    lock = open(
      directory.appendingPathComponent("owner.lock").path,
      O_CREAT | O_RDWR | O_NOFOLLOW | O_CLOEXEC, 0o600)
    guard lock >= 0 else { throw AppError("Cannot acquire the application lock.") }
    guard flock(lock, LOCK_EX | LOCK_NB) == 0 else {
      close(lock)
      throw AppError("DS4Mouse is already running.")
    }
    var info = stat()
    if lstat(path, &info) == 0 {
      guard info.st_uid == getuid(), info.st_mode & S_IFMT == S_IFSOCK else {
        close(lock)
        throw AppError("Refusing to replace an unexpected socket-path entry.")
      }
      unlink(path)
    }
    let fd = socket(AF_UNIX, SOCK_STREAM, 0)
    guard fd >= 0 else {
      close(lock)
      throw AppError("Cannot create the command listener.")
    }
    LocalSocket.configure(fd)
    do {
      var address = try LocalSocket.address(path)
      let result = withUnsafePointer(to: &address) {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
          bind(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
        }
      }
      guard result == 0, chmod(path, 0o600) == 0, listen(fd, 8) == 0 else {
        throw AppError("Could not bind the private command socket.")
      }
    } catch {
      close(fd)
      close(lock)
      throw error
    }
    source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: queue)
    source.setEventHandler { [weak self] in
      guard let self, !self.stopped else { return }
      let client = accept(fd, nil, nil)
      guard client >= 0 else { return }
      guard self.clients.count < 8 else {
        close(client)
        return
      }
      LocalSocket.configure(client)
      self.clients.insert(client)
      DispatchQueue.global(qos: .userInitiated).async {
        defer {
          self.queue.async {
            self.clients.remove(client)
            close(client)
          }
        }
        do {
          let deadline = ProcessInfo.processInfo.systemUptime + 3
          try LocalSocket.verifyPeer(client)
          let request = try JSONDecoder().decode(
            ControlRequest.self, from: LocalSocket.readLine(client, deadline: deadline))
          let reply = SocketReply()
          handler(request) { reply.set($0) }
          guard let response = reply.wait(until: deadline) else {
            throw AppError("The app did not respond before the command deadline.")
          }
          try LocalSocket.write(response, to: client)
        } catch {
          try? LocalSocket.write(
            ControlResponse(ok: false, exitCode: 3, message: error.localizedDescription), to: client
          )
        }
      }
    }
    let lockFD = lock
    let socketPath = path
    source.setCancelHandler {
      close(fd)
      unlink(socketPath)
      close(lockFD)
    }
    source.resume()
  }
  public func stop() {
    queue.async {
      guard !self.stopped else { return }
      self.stopped = true
      for client in self.clients { shutdown(client, SHUT_RDWR) }
      self.source.cancel()
    }
  }
}

private final class SocketReply: @unchecked Sendable {
  private let lock = NSLock()
  private let signal = DispatchSemaphore(value: 0)
  private var response: ControlResponse?
  func set(_ value: ControlResponse) {
    lock.lock()
    guard response == nil else {
      lock.unlock()
      return
    }
    response = value
    lock.unlock()
    signal.signal()
  }
  func wait(until deadline: Double) -> ControlResponse? {
    guard
      signal.wait(timeout: .now() + max(0, deadline - ProcessInfo.processInfo.systemUptime))
        == .success
    else { return nil }
    lock.lock()
    defer { lock.unlock() }
    return response
  }
}
