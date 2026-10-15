import Foundation
import Testing

@testable import DS4Core

struct AccelerationTests {
  @Test func fasterSwipesTravelFartherForTheSameFingerDistance() {
    var config = Configuration.defaults
    config.pointerAcceleration = 1
    var slow = MouseMapper(configuration: config)
    var fast = MouseMapper(configuration: config)
    _ = slow.handle(.motion("one-finger-move", 0.001, 0), at: 1)
    _ = fast.handle(.motion("one-finger-move", 0.001, 0), at: 1)
    let slowMove = slow.handle(.motion("one-finger-move", 0.001, 0), at: 1.1)
    let fastMove = fast.handle(.motion("one-finger-move", 0.001, 0), at: 1.004)
    guard case .move(let slowX, _) = slowMove.first,
      case .move(let fastX, _) = fastMove.first
    else {
      Issue.record("Expected pointer movement")
      return
    }
    #expect(fastX > slowX)
  }
  @Test func zeroAccelerationPreservesExistingPointerFeel() {
    var mapper = MouseMapper(configuration: .defaults)
    let output = mapper.handle(.motion("one-finger-move", 0.01, 0), at: 1)
    #expect(output == [.move(18, 0)])
  }
  @Test func existingSavedConfigurationLoadsWithAccelerationOff() throws {
    let data = try Configuration.defaults.encoded()
    var json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    json.removeValue(forKey: "pointerAcceleration")
    let restored = try Configuration.decode(JSONSerialization.data(withJSONObject: json))
    #expect(restored.pointerAcceleration == 0)
    #expect(restored.mappings == Configuration.defaults.mappings)
  }
  @Test func accelerationRangeIsValidatedThroughCLI() {
    #expect(throws: (any Error).self) {
      try CLICommand.parse(["set", "pointer-acceleration", "-1"])
    }
    #expect(throws: (any Error).self) {
      try CLICommand.parse(["set", "pointer-acceleration", "nan"])
    }
    #expect(throws: (any Error).self) {
      try CLICommand.parse(["set", "pointer-acceleration", "4"])
    }
  }
}
