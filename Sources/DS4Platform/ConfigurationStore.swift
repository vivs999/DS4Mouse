import DS4Core
import Foundation

public struct ConfigurationStore: Sendable {
  public let url: URL
  public init(url: URL? = nil) {
    self.url =
      url
      ?? FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent("Library/Application Support/DS4Mouse/config.json")
  }
  public func load() throws -> Configuration {
    guard FileManager.default.fileExists(atPath: url.path) else { return .defaults }
    let data = try Data(contentsOf: url)
    guard data.count <= 65536 else { throw AppError("Configuration exceeds 64 KiB.") }
    return try Configuration.decode(data)
  }
  public func save(_ configuration: Configuration) throws {
    let data = try configuration.encoded()
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(),
      withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
    try data.write(to: url, options: .atomic)
    try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
  }
  public func resetPreservingPrevious() throws {
    if FileManager.default.fileExists(atPath: url.path) {
      let backup = url.deletingLastPathComponent().appendingPathComponent(
        "config-backup-\(UUID().uuidString).json")
      try FileManager.default.copyItem(at: url, to: backup)
    }
    try save(.defaults)
  }
}
