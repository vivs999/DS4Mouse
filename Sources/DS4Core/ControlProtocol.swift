import Foundation

public struct ControllerDevice: Codable, Equatable, Sendable {
  public let id: String
  public let name: String
  public init(id: String, name: String) {
    self.id = id
    self.name = name
  }
}
public struct ServiceStatus: Codable, Sendable {
  public var running: Bool
  public var enabled: Bool
  public var ready: Bool
  public var permissionGranted: Bool
  public var selectedDevice: String?
  public var devices: [ControllerDevice]
  public var message: String
  public var validReports: Int
  public init(
    running: Bool = true, enabled: Bool = false, ready: Bool = false,
    permissionGranted: Bool = false, selectedDevice: String? = nil,
    devices: [ControllerDevice] = [], message: String = "Disabled", validReports: Int = 0
  ) {
    self.running = running
    self.enabled = enabled
    self.ready = ready
    self.permissionGranted = permissionGranted
    self.selectedDevice = selectedDevice
    self.devices = devices
    self.message = message
    self.validReports = validReports
  }
}
public struct ControlRequest: Codable, Sendable {
  public var protocolVersion = 1
  public var command: String
  public var arguments: [String]
  public var configuration: Configuration?
  public init(_ command: String, _ arguments: [String] = [], configuration: Configuration? = nil) {
    self.command = command
    self.arguments = arguments
    self.configuration = configuration
  }
}
public struct ControlResponse: Codable, Sendable {
  public var protocolVersion = 1
  public var ok: Bool
  public var exitCode: Int32
  public var message: String
  public var status: ServiceStatus?
  public var diagnostics: [String: String]?
  public var configuration: Configuration?
  public init(
    ok: Bool = true, exitCode: Int32 = 0, message: String,
    status: ServiceStatus? = nil, configuration: Configuration? = nil,
    diagnostics: [String: String]? = nil
  ) {
    self.ok = ok
    self.exitCode = exitCode
    self.message = message
    self.status = status
    self.diagnostics = diagnostics
    self.configuration = configuration
  }
}

public struct CLICommand: Sendable {
  public let request: ControlRequest
  public let json: Bool
  public let file: String?
  public let overwrite: Bool
  public let localOperation: String?
  public static func parse(_ input: [String]) throws -> CLICommand {
    let json = input.contains("--json")
    let overwrite = input.contains("--force")
    let args = input.filter { $0 != "--json" && $0 != "--force" }
    var request: ControlRequest
    var file: String?
    var operation: String?
    switch args.first ?? "help" {
    case "help", "--help", "-h":
      guard args.count <= 1 else { throw AppError("Unexpected help arguments.") }
      request = ControlRequest("help")
      operation = "help"
    case "on", "off", "toggle", "status", "doctor", "mappings":
      guard args.count == 1 else { throw AppError("Unexpected arguments. Run ds4mouse help.") }
      request = ControlRequest(args[0])
    case "map":
      guard args.count == 3, Configuration.actions(for: args[1]).contains(args[2]) else {
        throw AppError(
          "Use: ds4mouse map <input> <compatible-action>. Run ds4mouse mappings for names.")
      }
      request = ControlRequest("map", Array(args.dropFirst()))
    case "set":
      guard args.count == 3 else { throw AppError("Use: ds4mouse set <setting> <value>.") }
      var config = Configuration.defaults
      try config.set(args[1], to: args[2])
      request = ControlRequest("set", Array(args.dropFirst()))
    case "config":
      guard args.count >= 2 else { throw AppError("Use config export, import, or reset.") }
      if args[1] == "reset", args.count == 2 {
        request = ControlRequest("reset")
      } else if ["export", "import"].contains(args[1]), args.count == 3 {
        operation = args[1]
        file = args[2]
        request = ControlRequest(args[1] == "export" ? "mappings" : "replace")
      } else {
        throw AppError("Use: ds4mouse config export|import <path>, or config reset.")
      }
    default: throw AppError("Unknown command. Run ds4mouse help.")
    }
    if overwrite && operation != "export" {
      throw AppError("--force is only valid for config export.")
    }
    return CLICommand(
      request: request, json: json, file: file, overwrite: overwrite, localOperation: operation)
  }
}

extension Configuration {
  public mutating func set(_ key: String, to value: String) throws {
    switch key {
    case "pointer-speed": pointerSpeed = Double(value) ?? .nan
    case "pointer-acceleration": pointerAcceleration = Double(value) ?? .nan
    case "scroll-speed": scrollSpeed = Double(value) ?? .nan
    case "scroll-direction": scrollDirection = value
    default: throw AppError("Unknown setting: \(key).")
    }
    try validate()
  }
}
