import Foundation

public struct InputPipeline: Sendable {
  private var gestures = GestureEngine()
  private var samples = SampleTracker()
  private var buttons = ButtonTracker()
  private var mapper: MouseMapper
  private var primed = false
  private var contactIDs: [Int] = []
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
    for sample in report.samples where samples.accept(sample.counter) {
      let nextIDs = sample.contacts.map(\.id).sorted()
      if nextIDs != contactIDs {
        mapper.resetMotion()
        contactIDs = nextIDs
      }
      let events = gestures.consume(sample.contacts, at: now, dragging: mapper.dragging)
      if !primed {
        gestures.suppressTap()
      } else {
        for event in events { output += mapper.handle(event, at: now) }
      }
    }
    primed = true
    return output
  }
}
