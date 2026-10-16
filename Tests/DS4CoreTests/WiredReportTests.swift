import Testing

@testable import DS4Core

struct WiredReportTests {
  @Test func usbContactsAndButtonsUseTheWiredOffsets() throws {
    var bytes = usbPacket(counter: 7, contacts: [(4, 100, 200), (7, 1300, 800)])
    bytes[5] = 0x28  // Cross, neutral d-pad.
    bytes[6] = 1  // L1.
    bytes[7] = 2  // Touchpad button.
    bytes[8] = 255
    let report = try ReportParser.parse(bytes)
    #expect(report.samples.count == 1)
    #expect(report.samples[0].counter == 7)
    #expect(report.samples[0].contacts.map(\.id) == [4, 7])
    #expect(report.samples[0].contacts[0].x == 100.0 / 1920)
    #expect(report.samples[0].contacts[1].y == 800.0 / 944)
    #expect(report.buttons == ["button-cross", "button-l1", "touchpad-press"])
    #expect(report.leftTrigger == 1)
  }

  @Test func wiredTouchReportsProduceMovementTapAndBalancedDrag() throws {
    var pipeline = InputPipeline(configuration: .defaults)
    func consume(_ counter: UInt8, _ contacts: [(Int, Int, Int)], pressed: Bool = false)
      throws -> [MouseIntent]
    {
      var bytes = usbPacket(counter: counter, contacts: contacts)
      if pressed { bytes[7] = 2 }
      return pipeline.consume(try ReportParser.parse(bytes), at: 1 + Double(counter) * 0.02)
    }
    #expect(try consume(0, []).isEmpty)
    #expect(try consume(1, [(1, 400, 400)]).isEmpty)
    let motion = try consume(2, [(1, 600, 400)])
    #expect(motion.contains { if case .move(let x, _) = $0 { x > 0 } else { false } })
    _ = try consume(3, [])
    _ = try consume(4, [(2, 500, 400)])
    #expect(try consume(5, []) == [.click(.left, count: 1)])
    #expect(try consume(6, [(3, 500, 400)], pressed: true) == [.down(.left)])
    #expect(try consume(7, []) == [.up(.left)])
  }

  @Test func usbHistoryAcceptsThreeSamplesAndRejectsFour() throws {
    var bytes = usbPacket(counter: 7, contacts: [])
    bytes[33] = 3
    bytes[43] = 8
    bytes[44] = 0x80
    bytes[48] = 0x80
    bytes[52] = 9
    bytes[53] = 0x80
    bytes[57] = 0x80
    #expect(try ReportParser.parse(bytes).samples.map(\.counter) == [7, 8, 9])
    bytes[33] = 4
    #expect(throws: (any Error).self) { try ReportParser.parse(bytes) }
  }

  @Test func truncatedUSBPacketsAreRejected() {
    let bytes = usbPacket(counter: 0, contacts: [])
    for length in [0, 10, 32, 63] {
      #expect(throws: (any Error).self) { try ReportParser.parse(Array(bytes.prefix(length))) }
    }
  }

  private func usbPacket(counter: UInt8, contacts: [(Int, Int, Int)]) -> [UInt8] {
    var bytes = [UInt8](repeating: 0, count: 64)
    bytes[0] = 1
    bytes[5] = 8
    bytes[33] = 1
    bytes[34] = counter
    bytes[35] = 0x80
    bytes[39] = 0x80
    for (slot, point) in contacts.enumerated() {
      let offset = 35 + 4 * slot
      bytes[offset] = UInt8(point.0)
      bytes[offset + 1] = UInt8(point.1 & 255)
      bytes[offset + 2] = UInt8((point.1 >> 8) | ((point.2 & 15) << 4))
      bytes[offset + 3] = UInt8(point.2 >> 4)
    }
    return bytes
  }
}
