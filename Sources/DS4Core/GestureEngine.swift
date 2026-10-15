import Foundation

public struct GestureEngine: Sendable {
  private var previous: [Contact] = []
  private var origins: [Int: Contact] = [:]
  private var began: Double?
  private var maximumCount = 0
  private var tapAllowed = true
  private var twoFingerAllowed = true
  private var scrolling = false
  public init() {}
  public mutating func reset() { self = GestureEngine() }
  public mutating func suppressTap() { tapAllowed = false }

  public mutating func consume(_ contacts: [Contact], at now: Double, dragging: Bool)
    -> [InputEvent]
  {
    let current = contacts.sorted { $0.id < $1.id }
    if current.isEmpty {
      let allowed = began.map { now >= $0 && now - $0 <= 0.25 } ?? false
      let input = maximumCount == 2 ? "two-finger-tap" : "tap"
      let result: [InputEvent] =
        allowed && tapAllowed && !scrolling && !dragging
          && (maximumCount != 2 || twoFingerAllowed) ? [.activate(input)] : []
      reset()
      return result
    }
    if began == nil { began = now }
    if dragging { tapAllowed = false }
    if current.count == 2 && maximumCount < 2 && now - (began ?? now) > 0.1 {
      twoFingerAllowed = false
    }
    maximumCount = max(maximumCount, current.count)
    for point in current {
      if let origin = origins[point.id] {
        if abs(point.x - origin.x) > 0.015 || abs(point.y - origin.y) > 0.015 {
          tapAllowed = false
          if current.count == 2 { scrolling = true }
        }
      } else {
        if origins.count >= 2 { tapAllowed = false }
        origins[point.id] = point
      }
    }
    defer { previous = current }
    guard current.map(\.id) == previous.map(\.id) else { return [] }
    let moving = dragging ? Array(current.prefix(1)) : current
    let old = dragging ? Array(previous.prefix(1)) : previous
    let dx = zip(moving, old).reduce(0.0) { $0 + $1.0.x - $1.1.x } / Double(moving.count)
    let dy = zip(moving, old).reduce(0.0) { $0 + $1.0.y - $1.1.y } / Double(moving.count)
    guard dx != 0 || dy != 0 else { return [] }
    if current.count == 2 && !dragging && !scrolling { return [] }
    return [
      .motion(current.count == 2 && !dragging ? "two-finger-move" : "one-finger-move", dx, dy)
    ]
  }
}
