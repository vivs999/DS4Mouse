import Foundation

public enum CRC32 {
  public static func compute<S: Sequence>(_ data: S) -> UInt32 where S.Element == UInt8 {
    var crc: UInt32 = 0xFFFF_FFFF
    for byte in data {
      crc ^= UInt32(byte)
      for _ in 0..<8 { crc = (crc >> 1) ^ ((crc & 1) == 1 ? 0xEDB8_8320 : 0) }
    }
    return ~crc
  }
}

public enum ReportParser {
  public static func parse(_ data: [UInt8]) throws -> ControllerReport {
    guard let id = data.first else { throw AppError("Empty controller report.") }
    let offset: Int
    let capacity: Int
    if (0x11...0x19).contains(id) {
      guard data.count >= 78, data[1] & 0x80 != 0 else {
        throw AppError("Truncated Bluetooth report or missing HID payload.")
      }
      let expected = (0..<4).reduce(UInt32(0)) { $0 | UInt32(data[74 + $1]) << (8 * $1) }
      guard CRC32.compute([0xA1] + data.prefix(74)) == expected else {
        throw AppError("Bluetooth report checksum failed.")
      }
      offset = 3
      capacity = 4
    } else if id == 1, data.count == 64 || data.count == 128 {
      offset = 1
      capacity = 3
    } else if id == 1, data.count == 10 {
      throw AppError(
        "Controller is using basic Bluetooth reports; extended touch reports are required.")
    } else {
      throw AppError("Unsupported controller report ID/length: \(id)/\(data.count).")
    }
    let count = Int(data[offset + 32])
    guard count <= capacity else { throw AppError("Invalid touch-history count.") }
    var samples: [TouchSample] = []
    for sample in 0..<count {
      let start = offset + 33 + sample * 9
      var contacts: [Contact] = []
      for slot in 0..<2 {
        let p = start + 1 + 4 * slot
        guard data[p] & 0x80 == 0 else { continue }
        let x = Int(data[p + 1]) | (Int(data[p + 2] & 15) << 8)
        let y = Int(data[p + 2] >> 4) | (Int(data[p + 3]) << 4)
        let contactID = Int(data[p] & 0x7F)
        guard x < 1920, y < 944, !contacts.contains(where: { $0.id == contactID }) else {
          throw AppError("Invalid touch coordinate or duplicate contact ID.")
        }
        contacts.append(Contact(id: contactID, x: Double(x) / 1920, y: Double(y) / 944))
      }
      samples.append(TouchSample(counter: data[start], contacts: contacts))
    }
    let a = data[offset + 4]
    let b = data[offset + 5]
    let c = data[offset + 6]
    var buttons: Set<String> = []
    for (mask, key) in [
      (16, "button-square"), (32, "button-cross"), (64, "button-circle"), (128, "button-triangle"),
    ] {
      if a & UInt8(mask) != 0 { buttons.insert(key) }
    }
    for (mask, key) in [
      (1, "button-l1"), (2, "button-r1"), (16, "button-share"), (32, "button-options"),
      (64, "button-l3"), (128, "button-r3"),
    ] {
      if b & UInt8(mask) != 0 { buttons.insert(key) }
    }
    if c & 2 != 0 { buttons.insert("touchpad-press") }
    let hat = a & 15
    guard hat <= 8 else { throw AppError("Invalid direction-pad value.") }
    if [0, 1, 7].contains(hat) { buttons.insert("dpad-up") }
    if [1, 2, 3].contains(hat) { buttons.insert("dpad-right") }
    if [3, 4, 5].contains(hat) { buttons.insert("dpad-down") }
    if [5, 6, 7].contains(hat) { buttons.insert("dpad-left") }
    return ControllerReport(
      samples: samples, buttons: buttons,
      leftTrigger: Double(data[offset + 7]) / 255, rightTrigger: Double(data[offset + 8]) / 255)
  }
}
