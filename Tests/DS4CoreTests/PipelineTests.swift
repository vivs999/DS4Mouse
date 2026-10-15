import Testing

@testable import DS4Core

struct PipelineTests {
  @Test func repeatedHistoryNeverReplaysATapAfterIdle() {
    var pipeline = InputPipeline(configuration: .defaults)
    let history = ControllerReport(
      samples: [
        TouchSample(counter: 10, contacts: [Contact(id: 1, x: 0.4, y: 0.4)]),
        TouchSample(counter: 11, contacts: []),
      ], buttons: [], leftTrigger: 0, rightTrigger: 0)
    _ = pipeline.consume(history, at: 1)
    let replay = pipeline.consume(history, at: 1.6)
    #expect(replay.isEmpty)
  }
  @Test func firstHeldContactCannotCreateAPhantomClick() {
    var pipeline = InputPipeline(configuration: .defaults)
    let first = report(0, [Contact(id: 1, x: 0.5, y: 0.5)])
    let initial = pipeline.consume(first, at: 1)
    let release = pipeline.consume(report(1, []), at: 1.1)
    #expect(initial.isEmpty)
    #expect(release.isEmpty)
  }
  @Test func dragReleaseIsBalancedAndResetIsIdempotent() {
    var pipeline = InputPipeline(configuration: .defaults)
    _ = pipeline.consume(report(0, []), at: 1)
    let down = pipeline.consume(report(1, [], buttons: ["touchpad-press"]), at: 1.1)
    #expect(down == [.down(.left)])
    let firstRelease = pipeline.releaseAll()
    let secondRelease = pipeline.releaseAll()
    #expect(firstRelease == [.up(.left)])
    #expect(secondRelease.isEmpty)
  }
  @Test func physicalClickSuppressesTouchTap() {
    var pipeline = InputPipeline(configuration: .defaults)
    _ = pipeline.consume(report(0, []), at: 1)
    let contact = Contact(id: 1, x: 0.5, y: 0.5)
    _ = pipeline.consume(report(1, [contact]), at: 1.01)
    _ = pipeline.consume(report(2, [contact], buttons: ["touchpad-press"]), at: 1.05)
    let released = pipeline.consume(report(3, []), at: 1.1)
    #expect(released == [.up(.left)])
  }
  @Test func crcMatchesKnownVector() {
    #expect(CRC32.compute(Array("123456789".utf8)) == 0xCBF4_3926)
  }
  private func report(_ sequence: UInt8, _ contacts: [Contact], buttons: Set<String> = [])
    -> ControllerReport
  {
    ControllerReport(
      samples: [TouchSample(counter: sequence, contacts: contacts)],
      buttons: buttons, leftTrigger: 0, rightTrigger: 0)
  }
}
