import Foundation

public struct InputPipeline: Sendable {
  private var gestures = GestureEngine()
  private var samples = SampleTracker()
  private var buttons = ButtonTracker()
  private var mapper: MouseMapper
  private var primed = false
  private var contactIDs: [Int] = []
  private var touchReportTime: Double?
  public init(configuration: Configuration) { mapper = MouseMapper(configuration: configuration) }
  public mutating func releaseAll() -> [MouseIntent] { mapper.releaseAll() }

  public mutating func consume(_ report: ControllerReport, at now: Double) -> [MouseIntent] {
    var output: [MouseIntent] = []
    if !primed { buttons.seed(report) }
    for event in buttons.consume(report) {
      if event == .activate("touchpad-press") { gestures.suppressTap() }
      output += mapper.handle(event, at: now)
    }
    if mapper.dragging { gestures.suppressTap() }
    let freshSamples = report.samples.filter { samples.accept($0.counter) }
    // Bluetooth reports may contain several fresh samples. Distribute their timing
    // across the report interval so batching does not change pointer acceleration.
    let interval = touchReportTime.map { max(0, now - $0) } ?? (1.0 / 60)
    for (index, sample) in freshSamples.enumerated() {
      let sampleTime =
        now - interval * Double(freshSamples.count - index - 1)
        / Double(freshSamples.count)
      let nextIDs = sample.contacts.map(\.id).sorted()
      if nextIDs != contactIDs {
        mapper.resetMotion()
        contactIDs = nextIDs
      }
      let events = gestures.consume(sample.contacts, at: sampleTime, dragging: mapper.dragging)
      if !primed {
        gestures.suppressTap()
      } else {
        for event in events { output += mapper.handle(event, at: sampleTime) }
      }
    }
    if !freshSamples.isEmpty { touchReportTime = now }
    primed = true
    return output
  }
}
