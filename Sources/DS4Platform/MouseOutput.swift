import AppKit
import ApplicationServices
import CoreGraphics
import DS4Core
import IOKit.hidsystem

@MainActor public final class MouseOutput {
  private let source = CGEventSource(stateID: .hidSystemState)
  private var held: Set<MouseButton> = []
  private var remainder = CGPoint.zero
  private var scrollRemainder = CGPoint.zero
  private var lastClick: (MouseButton, Double, CGPoint, Int)?
  public init() { source?.localEventsSuppressionInterval = 0 }
  public var permissionSettingsName: String {
    ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 27
      ? "Device Control and Data Access" : "Accessibility"
  }
  public var permissionDiagnostics: [String: String] {
    [
      "postEventAccess": String(CGPreflightPostEventAccess()),
      "accessibilityTrusted": String(AXIsProcessTrusted()),
      "hidPostAccess": String(IOHIDCheckAccess(kIOHIDRequestTypePostEvent).rawValue),
      "hidListenAccess": String(IOHIDCheckAccess(kIOHIDRequestTypeListenEvent).rawValue),
      "bundlePath": Bundle.main.bundleURL.path,
      "bundleIdentifier": Bundle.main.bundleIdentifier ?? "unknown",
    ]
  }
  public var permitted: Bool { CGPreflightPostEventAccess() }
  public func requestPermission() { _ = CGRequestPostEventAccess() }

  public func send(_ intents: [MouseIntent]) {
    for intent in intents {
      switch intent {
      case .up(let button):
        buttonEvent(button, down: false, count: lastClick?.3 ?? 1)
        held.remove(button)
      case .down(let button):
        guard permitted else { continue }
        held.insert(button)
        buttonEvent(button, down: true, count: clickCount(button))
      case .click(let button, let count):
        guard permitted, !held.contains(button) else { continue }
        for number in 1...count {
          let click = count == 1 ? clickCount(button) : number
          buttonEvent(button, down: true, count: click)
          buttonEvent(button, down: false, count: click)
        }
      case .move(let dx, let dy): move(dx, dy)
      case .scroll(let dx, let dy, let lines): scroll(dx, dy, lines: lines)
      }
    }
  }
  public func releaseAll() {
    for button in held { buttonEvent(button, down: false, count: 1) }
    held.removeAll()
    remainder = .zero
    scrollRemainder = .zero
  }

  private func clickCount(_ button: MouseButton) -> Int {
    let now = ProcessInfo.processInfo.systemUptime
    let point = CGEvent(source: nil)?.location ?? .zero
    var count = 1
    if let last = lastClick, last.0 == button, now - last.1 <= NSEvent.doubleClickInterval,
      hypot(point.x - last.2.x, point.y - last.2.y) <= 4
    {
      count = min(3, last.3 + 1)
    }
    lastClick = (button, now, point, count)
    return count
  }
  private func buttonEvent(_ button: MouseButton, down: Bool, count: Int) {
    guard permitted else { return }
    let type: CGEventType
    switch button {
    case .left: type = down ? .leftMouseDown : .leftMouseUp
    case .right: type = down ? .rightMouseDown : .rightMouseUp
    default: type = down ? .otherMouseDown : .otherMouseUp
    }
    let event = CGEvent(
      mouseEventSource: source, mouseType: type,
      mouseCursorPosition: CGEvent(source: nil)?.location ?? .zero,
      mouseButton: CGMouseButton(rawValue: button.number)!)
    event?.setIntegerValueField(.mouseEventClickState, value: Int64(count))
    event?.post(tap: .cghidEventTap)
  }
  private func move(_ dx: Double, _ dy: Double) {
    guard permitted else { return }
    remainder.x += dx
    remainder.y += dy
    let x = remainder.x.rounded(.towardZero)
    let y = remainder.y.rounded(.towardZero)
    remainder.x -= x
    remainder.y -= y
    guard x != 0 || y != 0 else { return }
    let current = CGEvent(source: nil)?.location ?? .zero
    let target = confined(CGPoint(x: current.x + x, y: current.y + y))
    let button = MouseButton.allCases.first { held.contains($0) }
    let type: CGEventType
    switch button {
    case .left: type = .leftMouseDragged
    case .right: type = .rightMouseDragged
    case .some: type = .otherMouseDragged
    case .none: type = .mouseMoved
    }
    let event = CGEvent(
      mouseEventSource: source, mouseType: type, mouseCursorPosition: target,
      mouseButton: CGMouseButton(rawValue: button?.number ?? 0)!)
    event?.setIntegerValueField(.mouseEventDeltaX, value: Int64(target.x - current.x))
    event?.setIntegerValueField(.mouseEventDeltaY, value: Int64(target.y - current.y))
    event?.post(tap: .cghidEventTap)
  }
  private func scroll(_ dx: Double, _ dy: Double, lines: Bool) {
    guard permitted else { return }
    scrollRemainder.x += dx
    scrollRemainder.y += dy
    let x = Int32(scrollRemainder.x.rounded(.towardZero))
    let y = Int32(scrollRemainder.y.rounded(.towardZero))
    scrollRemainder.x -= Double(x)
    scrollRemainder.y -= Double(y)
    guard x != 0 || y != 0 else { return }
    CGEvent(
      scrollWheelEvent2Source: source, units: lines ? .line : .pixel,
      wheelCount: 2, wheel1: y, wheel2: x, wheel3: 0)?.post(tap: .cghidEventTap)
  }
  private func confined(_ point: CGPoint) -> CGPoint {
    var displays = [CGDirectDisplayID](repeating: 0, count: 32)
    var count: UInt32 = 0
    guard CGGetActiveDisplayList(32, &displays, &count) == .success, count > 0 else { return point }
    let bounds = displays.prefix(Int(count)).map(CGDisplayBounds)
    if bounds.contains(where: { $0.contains(point) }) { return point }
    return bounds.map { rect in
      CGPoint(
        x: min(max(point.x, rect.minX), rect.maxX - 1),
        y: min(max(point.y, rect.minY), rect.maxY - 1))
    }.min { hypot($0.x - point.x, $0.y - point.y) < hypot($1.x - point.x, $1.y - point.y) } ?? point
  }
}
