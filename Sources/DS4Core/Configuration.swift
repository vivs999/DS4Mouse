import Foundation

public struct AppError: Error, LocalizedError, Sendable {
  public let message: String
  public init(_ message: String) { self.message = message }
  public var errorDescription: String? { message }
}

public struct Configuration: Codable, Equatable, Sendable {
  public var schemaVersion = 1
  public var pointerSpeed = 1.0
  public var pointerAcceleration = 0.0
  public var scrollSpeed = 1.0
  public var scrollDirection = "natural"
  public var mappings: [String: String] = [:]

  public init() {}
  private enum CodingKeys: String, CodingKey {
    case schemaVersion, pointerSpeed, pointerAcceleration, scrollSpeed, scrollDirection, mappings
  }
  public init(from decoder: any Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    schemaVersion = try values.decode(Int.self, forKey: .schemaVersion)
    pointerSpeed = try values.decode(Double.self, forKey: .pointerSpeed)
    pointerAcceleration = try values.decodeIfPresent(Double.self, forKey: .pointerAcceleration) ?? 0
    scrollSpeed = try values.decode(Double.self, forKey: .scrollSpeed)
    scrollDirection = try values.decode(String.self, forKey: .scrollDirection)
    mappings = try values.decode([String: String].self, forKey: .mappings)
  }

  public static let movementInputs = ["one-finger-move", "two-finger-move"]
  public static let tapInputs = ["tap", "two-finger-tap"]
  public static let buttonInputs = [
    "touchpad-press", "button-cross", "button-circle", "button-square", "button-triangle",
    "button-l1", "button-r1", "button-l2", "button-r2", "button-l3", "button-r3",
    "button-share", "button-options", "dpad-up", "dpad-down", "dpad-left", "dpad-right",
  ]
  public static var allInputs: [String] { movementInputs + tapInputs + buttonInputs }
  public static let clickActions = [
    "disabled", "left-click", "right-click", "middle-click", "back-click", "forward-click",
    "double-click", "scroll-up", "scroll-down", "scroll-left", "scroll-right",
  ]
  public static func actions(for input: String) -> [String] {
    if movementInputs.contains(input) { return ["disabled", "pointer", "scroll"] }
    if buttonInputs.contains(input) {
      return clickActions + MouseButton.allCases.map { "hold:\($0.rawValue)" }
    }
    return tapInputs.contains(input) ? clickActions : []
  }
  public static var defaults: Configuration {
    var result = Configuration()
    result.mappings = Dictionary(uniqueKeysWithValues: allInputs.map { ($0, "disabled") })
    result.mappings["one-finger-move"] = "pointer"
    result.mappings["two-finger-move"] = "scroll"
    result.mappings["tap"] = "left-click"
    result.mappings["two-finger-tap"] = "right-click"
    result.mappings["touchpad-press"] = "hold:left"
    return result
  }
  public func validate() throws {
    guard schemaVersion == 1 else {
      throw AppError("Unsupported configuration version: \(schemaVersion).")
    }
    for (name, value) in [("pointer-speed", pointerSpeed), ("scroll-speed", scrollSpeed)] {
      guard value.isFinite && (0.1...5).contains(value) else {
        throw AppError("\(name) must be a number from 0.1 to 5.0.")
      }
    }
    guard pointerAcceleration.isFinite && (0...3).contains(pointerAcceleration) else {
      throw AppError("pointer-acceleration must be a number from 0.0 to 3.0 (0 turns it off).")
    }
    guard ["natural", "traditional"].contains(scrollDirection) else {
      throw AppError("Scroll direction must be natural or traditional.")
    }
    guard Set(mappings.keys) == Set(Self.allInputs) else {
      throw AppError(
        "Configuration must contain exactly the supported input names. Export the default configuration as a template."
      )
    }
    for (input, action) in mappings where !Self.actions(for: input).contains(action) {
      throw AppError(
        "Action '\(action)' cannot be assigned to '\(input)'. Allowed: \(Self.actions(for: input).joined(separator: ", "))."
      )
    }
  }
  public func encoded() throws -> Data {
    try validate()
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    return try encoder.encode(self)
  }
  public static func decode(_ data: Data) throws -> Configuration {
    let value = try JSONDecoder().decode(Configuration.self, from: data)
    try value.validate()
    return value
  }
}
