import DS4Core
import Darwin
import Foundation
import Testing

@testable import DS4Platform

struct PlatformTests {
  @Test func missingListenerIsDistinguishedFromAnUncertainCommand() throws {
    let folder = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: folder) }
    do {
      _ = try LocalSocket.request(ControlRequest("off"), in: folder)
      Issue.record("Expected no listener")
    } catch LocalConnectionError.notRunning {}
    let server = try LocalServer(directory: folder) { _, _ in }
    defer { server.stop() }
    do {
      let response = try LocalSocket.request(ControlRequest("toggle"), in: folder)
      #expect(response.exitCode == 3)
    } catch LocalConnectionError.failed {}
  }
  @Test func partialClientDoesNotBlockOtherCommands() throws {
    let folder = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: folder) }
    let server = try LocalServer(directory: folder) { request, reply in
      reply(ControlResponse(message: request.command))
    }
    defer { server.stop() }
    let fd = socket(AF_UNIX, SOCK_STREAM, 0)
    defer { close(fd) }
    var address = try LocalSocket.address(folder.appendingPathComponent("control.sock").path)
    let connected = withUnsafePointer(to: &address) {
      $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
        connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
      }
    }
    #expect(connected == 0)
    var byte: UInt8 = 123
    _ = send(fd, &byte, 1, 0)
    let began = ProcessInfo.processInfo.systemUptime
    let response = try LocalSocket.request(ControlRequest("off"), in: folder)
    #expect(response.message == "off")
    #expect(ProcessInfo.processInfo.systemUptime - began < 2)
  }
  @Test func invalidSavePreservesPreviousConfiguration() throws {
    let folder = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: folder) }
    let store = ConfigurationStore(url: folder.appendingPathComponent("config.json"))
    try store.save(.defaults)
    let original = try Data(contentsOf: store.url)
    var invalid = Configuration.defaults
    invalid.pointerSpeed = 0
    #expect(throws: (any Error).self) { try store.save(invalid) }
    #expect(try Data(contentsOf: store.url) == original)
  }
  @Test func corruptConfigurationIsNotOverwrittenOnLoad() throws {
    let folder = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: folder) }
    let store = ConfigurationStore(url: folder.appendingPathComponent("config.json"))
    let invalid = Data("invalid json".utf8)
    try invalid.write(to: store.url)
    #expect(throws: (any Error).self) { try store.load() }
    #expect(try Data(contentsOf: store.url) == invalid)
    try store.resetPreservingPrevious()
    #expect(try store.load() == .defaults)
    #expect(
      try FileManager.default.contentsOfDirectory(atPath: folder.path).contains {
        $0.hasPrefix("config-backup-")
      })
  }
  @Test func realLocalSocketRoundTripAndDuplicateOwnerRejection() throws {
    let folder = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: folder) }
    let server = try LocalServer(directory: folder) { request, completion in
      completion(ControlResponse(message: request.command, configuration: .defaults))
    }
    defer { server.stop() }
    let response = try LocalSocket.request(ControlRequest("mappings"), in: folder)
    #expect(response.message == "mappings")
    #expect(response.configuration == .defaults)
    #expect(throws: (any Error).self) { try LocalServer(directory: folder) { _, _ in } }
  }
  private func temporaryDirectory() throws -> URL {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(
      "d4-\(UUID().uuidString.prefix(8))")
    try FileManager.default.createDirectory(
      at: folder, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
    return folder
  }
}
