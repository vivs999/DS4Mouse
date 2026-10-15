import Foundation

public struct Contact: Equatable, Sendable {
  public let id: Int
  public let x: Double
  public let y: Double
  public init(id: Int, x: Double, y: Double) {
    self.id = id
    self.x = x
    self.y = y
  }
}
public struct TouchSample: Sendable {
  public let counter: UInt8
  public let contacts: [Contact]
}
public struct ControllerReport: Sendable {
  public let samples: [TouchSample]
  public let buttons: Set<String>
  public let leftTrigger: Double
  public let rightTrigger: Double
}
public enum InputEvent: Equatable, Sendable {
  case activate(String)
  case deactivate(String)
  case motion(String, Double, Double)
}
public enum MouseButton: String, CaseIterable, Codable, Sendable {
  case left, right, middle, back, forward
  public var number: UInt32 {
    switch self {
    case .left: 0
    case .right: 1
    case .middle: 2
    case .back: 3
    case .forward: 4
    }
  }
}
public enum MouseIntent: Equatable, Sendable {
  case move(Double, Double)
  case scroll(Double, Double, lines: Bool)
  case down(MouseButton)
  case up(MouseButton)
  case click(MouseButton, count: Int)
}
public struct SampleTracker: Sendable {
  private var last: UInt8?
  public init() {}
  public mutating func accept(_ counter: UInt8) -> Bool {
    if let last {
      let distance = counter &- last
      guard distance > 0 && distance < 128 else { return false }
    }
    last = counter
    return true
  }
}

public struct ButtonTracker: Sendable {
  private var pressed: Set<String> = []
  public init() {}
  public mutating func consume(_ report: ControllerReport) -> [InputEvent] {
    var next = report.buttons
    for (key, value) in [("button-l2", report.leftTrigger), ("button-r2", report.rightTrigger)] {
      if value >= (pressed.contains(key) ? 0.45 : 0.55) { next.insert(key) }
    }
    let events =
      pressed.subtracting(next).sorted().map(InputEvent.deactivate)
      + next.subtracting(pressed).sorted().map(InputEvent.activate)
    pressed = next
    return events
  }
  public mutating func seed(_ report: ControllerReport) { _ = consume(report) }
}
