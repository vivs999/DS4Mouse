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
  @Test func batchingTouchHistoryPreservesAcceleration() {
    var config = Configuration.defaults
    config.pointerAcceleration = 1
    var individual = InputPipeline(configuration: config)
    var batched = InputPipeline(configuration: config)
    func sample(_ counter: UInt8, _ x: Double) -> TouchSample {
      TouchSample(counter: counter, contacts: [Contact(id: 1, x: x, y: 0.5)])
    }
    func report(_ samples: [TouchSample]) -> ControllerReport {
      ControllerReport(samples: samples, buttons: [], leftTrigger: 0, rightTrigger: 0)
    }
    for (time, touch) in [(1.0, sample(0, 0.5)), (1.01, sample(1, 0.505))] {
      _ = individual.consume(report([touch]), at: time)
      _ = batched.consume(report([touch]), at: time)
    }
    let first = sample(2, 0.51)
    let second = sample(3, 0.515)
    let separate =
      individual.consume(report([first]), at: 1.02)
      + individual.consume(report([second]), at: 1.03)
    let combined = batched.consume(report([first, second]), at: 1.03)
    func travel(_ intents: [MouseIntent]) -> Double {
      intents.reduce(0) { total, intent in
        if case .move(let x, _) = intent { return total + x }
        return total
      }
    }
    #expect(abs(travel(separate) - travel(combined)) < 0.000001)
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
