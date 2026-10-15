import Testing

@testable import DS4Core

struct CoreTests {
  @Test func testDefaultsAndMappingValidation() throws {
    let config = Configuration.defaults
    assertEqual(config.mappings["tap"], "left-click")
    assertEqual(config.mappings["touchpad-press"], "hold:left")
    try config.validate()
    var bad = config
    bad.mappings["tap"] = "hold:left"
    #expect(throws: (any Error).self) { try bad.validate() }
    bad = config
    bad.pointerSpeed = .nan
    #expect(throws: (any Error).self) { try bad.validate() }
    bad = config
    bad.schemaVersion = 99
    #expect(throws: (any Error).self) { try bad.validate() }
  }

  @Test func testTruncatedAndCorruptReportsAreRejected() {
    #expect(throws: (any Error).self) { try ReportParser.parse([0x11]) }
    #expect(throws: (any Error).self) { try ReportParser.parse(Array(repeating: 0, count: 78)) }
    var report = packet(contacts: [(4, 100, 200)])
    report[40] ^= 1
    #expect(throws: (any Error).self) { try ReportParser.parse(report) }
  }

  @Test func testBluetoothContactDecoding() throws {
    let result = try ReportParser.parse(packet(contacts: [(4, 100, 200), (7, 1300, 800)]))
    assertEqual(result.samples.count, 1)
    assertEqual(result.samples[0].contacts.map(\.id), [4, 7])
    assertEqual(result.samples[0].contacts[0].x, 100.0 / 1920, accuracy: 0.0001)
    assertEqual(result.samples[0].contacts[0].y, 200.0 / 944, accuracy: 0.0001)
  }

  @Test func testInactiveContactCoordinatesAreIgnored() throws {
    var report = packet(contacts: [])
    report[38] = 255
    report[39] = 255
    report[40] = 255
    checksum(&report)
    assertEqual(try ReportParser.parse(report).samples[0].contacts, [])
  }

  @Test func testTapAndScrollAreMutuallyExclusive() {
    var engine = GestureEngine()
    _ = engine.consume([contact(1, 0.3, 0.3)], at: 1, dragging: false)
    assertEqual(engine.consume([], at: 1.1, dragging: false), [.activate("tap")])
    _ = engine.consume([contact(1, 0.3, 0.3), contact(2, 0.6, 0.3)], at: 2, dragging: false)
    let events = engine.consume(
      [contact(1, 0.3, 0.5), contact(2, 0.6, 0.5)], at: 2.1, dragging: false)
    assertTrue(
      events.contains { if case .motion("two-finger-move", _, _) = $0 { true } else { false } })
    assertEqual(engine.consume([], at: 2.2, dragging: false), [])
  }

  @Test func testTwoFingerTapDoesNotLeftClick() {
    var engine = GestureEngine()
    _ = engine.consume([contact(1, 0.3, 0.3)], at: 1, dragging: false)
    _ = engine.consume([contact(1, 0.3, 0.3), contact(2, 0.6, 0.3)], at: 1.03, dragging: false)
    _ = engine.consume([contact(2, 0.6, 0.3)], at: 1.1, dragging: false)
    assertEqual(engine.consume([], at: 1.15, dragging: false), [.activate("two-finger-tap")])
  }

  @Test func testReorderingContactsDoesNotMovePointer() {
    var engine = GestureEngine()
    let a = contact(1, 0.2, 0.4)
    let b = contact(2, 0.8, 0.4)
    _ = engine.consume([a, b], at: 1, dragging: false)
    assertEqual(engine.consume([b, a], at: 1.02, dragging: false), [])
  }

  @Test func testResetAndFreshContactHaveNoJump() {
    var engine = GestureEngine()
    _ = engine.consume([contact(1, 0.1, 0.1)], at: 1, dragging: false)
    engine.reset()
    assertEqual(engine.consume([contact(2, 0.9, 0.9)], at: 2, dragging: false), [])
  }

  @Test func testOverlappingHoldsReleaseOnlyOnce() throws {
    var config = Configuration.defaults
    config.mappings["button-cross"] = "hold:left"
    var mapper = MouseMapper(configuration: config)
    assertEqual(mapper.handle(.activate("touchpad-press")), [.down(.left)])
    assertEqual(mapper.handle(.activate("button-cross")), [])
    assertEqual(mapper.handle(.deactivate("touchpad-press")), [])
    assertEqual(mapper.releaseAll(), [.up(.left)])
    assertEqual(mapper.releaseAll(), [])
  }

  @Test func testClickCannotReleaseAnExistingHold() {
    var mapper = MouseMapper(configuration: .defaults)
    _ = mapper.handle(.activate("touchpad-press"))
    assertEqual(mapper.handle(.activate("tap")), [])
    assertEqual(mapper.handle(.deactivate("touchpad-press")), [.up(.left)])
  }

  @Test func testDuplicateAndWrappedTouchCounters() {
    var tracker = SampleTracker()
    assertTrue(tracker.accept(254))
    assertFalse(tracker.accept(254))
    assertTrue(tracker.accept(255))
    assertTrue(tracker.accept(0))
    assertFalse(tracker.accept(255))
  }

  private func contact(_ id: Int, _ x: Double, _ y: Double) -> Contact {
    Contact(id: id, x: x, y: y)
  }

  private func packet(contacts: [(Int, Int, Int)]) -> [UInt8] {
    var data = [UInt8](repeating: 0, count: 78)
    data[0] = 0x11
    data[1] = 0x80
    data[7] = 8
    data[35] = 1
    data[36] = 7
    data[37] = 0x80
    data[41] = 0x80
    for (slot, point) in contacts.enumerated() {
      let offset = 37 + 4 * slot
      data[offset] = UInt8(point.0)
      data[offset + 1] = UInt8(point.1 & 255)
      data[offset + 2] = UInt8((point.1 >> 8) | ((point.2 & 15) << 4))
      data[offset + 3] = UInt8(point.2 >> 4)
    }
    checksum(&data)
    return data
  }

  private func checksum(_ data: inout [UInt8]) {
    let crc = CRC32.compute([0xA1] + data.prefix(74))
    for i in 0..<4 { data[74 + i] = UInt8(truncatingIfNeeded: crc >> (8 * i)) }
  }
}

private func assertEqual<T: Equatable>(
  _ actual: T, _ expected: T, sourceLocation: SourceLocation = #_sourceLocation
) {
  #expect(actual == expected, sourceLocation: sourceLocation)
}
private func assertEqual(
  _ actual: Double, _ expected: Double, accuracy: Double,
  sourceLocation: SourceLocation = #_sourceLocation
) {
  #expect(abs(actual - expected) <= accuracy, sourceLocation: sourceLocation)
}
private func assertTrue(_ condition: Bool, sourceLocation: SourceLocation = #_sourceLocation) {
  #expect(condition, sourceLocation: sourceLocation)
}
private func assertFalse(_ condition: Bool, sourceLocation: SourceLocation = #_sourceLocation) {
  #expect(!condition, sourceLocation: sourceLocation)
}
