import Foundation
import Testing

@testable import DS4Core

struct CommandTests {
  @Test func rejectsUnknownInputsAndInvalidSpeeds() {
    #expect(throws: (any Error).self) { try CLICommand.parse(["map", "invalid", "left-click"]) }
    #expect(throws: (any Error).self) { try CLICommand.parse(["set", "pointer-speed", "nan"]) }
    #expect(throws: (any Error).self) { try CLICommand.parse(["map", "tap", "hold:left"]) }
    #expect(throws: (any Error).self) { try CLICommand.parse(["on", "extra"]) }
  }
  @Test func parsesJSONAndRoundTripsConfiguration() throws {
    let parsed = try CLICommand.parse(["status", "--json"])
    #expect(parsed.json)
    #expect(parsed.request.command == "status")
    #expect(try Configuration.decode(Configuration.defaults.encoded()) == .defaults)
  }
  @Test func counterGapRecoversAfterLongIdle() {
    var tracker = SampleTracker()
    let first = tracker.accept(1)
    let stale = tracker.accept(200)
    #expect(first)
    #expect(!stale)
    tracker = SampleTracker()
    let recovered = tracker.accept(200)
    #expect(recovered)
  }
}
