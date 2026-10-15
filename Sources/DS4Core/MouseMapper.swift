import Foundation

public struct MouseMapper: Sendable {
  public let configuration: Configuration
  private var owners: [String: MouseButton] = [:]
  private var motionTime: Double?
  private var motionGain = 1.0
  public var dragging: Bool { !owners.isEmpty }
  public init(configuration: Configuration) { self.configuration = configuration }

  public mutating func releaseAll() -> [MouseIntent] {
    let held = Set(owners.values)
    owners.removeAll()
    return MouseButton.allCases.filter { held.contains($0) }.map(MouseIntent.up)
  }
  public mutating func resetMotion() {
    motionTime = nil
    motionGain = 1
  }
  public mutating func handle(
    _ event: InputEvent, at now: Double = ProcessInfo.processInfo.systemUptime
  ) -> [MouseIntent] {
    switch event {
    case .deactivate(let input):
      guard let button = owners.removeValue(forKey: input), !owners.values.contains(button) else {
        return []
      }
      return [.up(button)]
    case .motion(let input, let dx, let dy):
      switch configuration.mappings[input] {
      case "pointer":
        let elapsed = motionTime.map { now - $0 } ?? (1.0 / 60)
        if elapsed > 0 {
          let interval = min(0.1, max(0.004, elapsed))
          let velocity = hypot(dx * 1800, dy * 885) / interval
          let fraction = min(1, max(0, (velocity - 80) / 1600))
          let curve = fraction * fraction * (3 - 2 * fraction)
          motionGain = 1 + configuration.pointerAcceleration * 2 * curve
          motionTime = now
        }
        return [
          .move(
            dx * 1800 * configuration.pointerSpeed * motionGain,
            dy * 885 * configuration.pointerSpeed * motionGain)
        ]
      case "scroll":
        let direction = configuration.scrollDirection == "natural" ? -1.0 : 1.0
        return [
          .scroll(
            dx * 1000 * configuration.scrollSpeed * direction,
            dy * 500 * configuration.scrollSpeed * direction, lines: false)
        ]
      default: return []
      }
    case .activate(let input):
      let action = configuration.mappings[input] ?? "disabled"
      if action.hasPrefix("hold:"), let button = MouseButton(rawValue: String(action.dropFirst(5)))
      {
        let alreadyHeld = owners.values.contains(button)
        owners[input] = button
        return alreadyHeld ? [] : [.down(button)]
      }
      if action == "double-click" {
        return owners.values.contains(.left) ? [] : [.click(.left, count: 2)]
      }
      if action.hasSuffix("-click"), let button = MouseButton(rawValue: String(action.dropLast(6)))
      {
        return owners.values.contains(button) ? [] : [.click(button, count: 1)]
      }
      let distance = 3 * configuration.scrollSpeed
      switch action {
      case "scroll-up": return [.scroll(0, distance, lines: true)]
      case "scroll-down": return [.scroll(0, -distance, lines: true)]
      case "scroll-left": return [.scroll(distance, 0, lines: true)]
      case "scroll-right": return [.scroll(-distance, 0, lines: true)]
      default: return []
      }
    }
  }
}
