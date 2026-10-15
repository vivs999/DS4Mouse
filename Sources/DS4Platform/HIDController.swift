import DS4Core
import Foundation
import IOKit.hid

@MainActor public final class HIDController {
  private let manager = IOHIDManagerCreate(kCFAllocatorDefault, 0)
  private var sessions: [String: HIDSession] = [:]
  public var onDevices: (([ControllerDevice]) -> Void)?
  public var onReport: ((String, [UInt8]) -> Void)?
  public var onError: ((String) -> Void)?
  public init() {}

  public func start() {
    let matches: [[String: Any]] = [0x05C4, 0x09CC].map {
      [
        kIOHIDVendorIDKey: 0x054C, kIOHIDProductIDKey: $0,
        kIOHIDTransportKey: "Bluetooth", kIOHIDPrimaryUsagePageKey: 1, kIOHIDPrimaryUsageKey: 5,
      ]
    }
    IOHIDManagerSetDeviceMatchingMultiple(manager, matches as CFArray)
    let context = Unmanaged.passUnretained(self).toOpaque()
    IOHIDManagerRegisterDeviceMatchingCallback(
      manager,
      { context, _, _, device in
        guard let context else { return }
        MainActor.assumeIsolated {
          Unmanaged<HIDController>.fromOpaque(context).takeUnretainedValue().attach(device)
        }
      }, context)
    IOHIDManagerRegisterDeviceRemovalCallback(
      manager,
      { context, _, _, device in
        guard let context else { return }
        MainActor.assumeIsolated {
          Unmanaged<HIDController>.fromOpaque(context).takeUnretainedValue().detach(device)
        }
      }, context)
    IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
    let result = IOHIDManagerOpen(manager, 0)
    if result != kIOReturnSuccess {
      onError?("Cannot open controller input (\(result)). Check Input Monitoring permission.")
    }
  }

  public func stop() {
    for session in sessions.values { session.close() }
    sessions.removeAll()
    IOHIDManagerUnscheduleFromRunLoop(
      manager, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
    IOHIDManagerClose(manager, 0)
  }

  private func deviceID(_ device: IOHIDDevice) -> String {
    var value: UInt64 = 0
    IORegistryEntryGetRegistryEntryID(IOHIDDeviceGetService(device), &value)
    return String(value)
  }

  private func attach(_ device: IOHIDDevice) {
    let id = deviceID(device)
    guard sessions[id] == nil else { return }
    let name =
      IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) as? String ?? "DualShock 4"
    let session = HIDSession(device: device, id: id, name: name, owner: self)
    sessions[id] = session
    session.open()
    publishDevices()
  }

  private func detach(_ device: IOHIDDevice) {
    sessions.removeValue(forKey: deviceID(device))?.close()
    publishDevices()
  }

  private func publishDevices() {
    onDevices?(
      sessions.values.map { ControllerDevice(id: $0.id, name: $0.name) }.sorted { $0.id < $1.id })
  }
}

@MainActor private final class HIDSession {
  let device: IOHIDDevice
  let id: String
  let name: String
  weak var owner: HIDController?
  private let storage = HIDReportBuffer()
  private var buffer: UnsafeMutablePointer<UInt8> { storage.bytes }
  private var initialized = false
  private var opened = false

  init(device: IOHIDDevice, id: String, name: String, owner: HIDController) {
    self.device = device
    self.id = id
    self.name = name
    self.owner = owner
  }

  func open() {
    let result = IOHIDDeviceOpen(device, 0)
    guard result == kIOReturnSuccess else {
      owner?.onError?(
        "Controller access failed (\(result)). Close conflicting controller apps or check Input Monitoring."
      )
      return
    }
    opened = true
    IOHIDDeviceRegisterInputReportCallback(
      device, buffer, 4096,
      { context, result, _, _, reportID, bytes, length in
        guard result == kIOReturnSuccess, let context, length > 0, length <= 4096 else { return }
        let copied = Array(UnsafeBufferPointer(start: bytes, count: length))
        MainActor.assumeIsolated {
          let session = Unmanaged<HIDSession>.fromOpaque(context).takeUnretainedValue()
          session.received(copied, reportID: reportID)
        }
      }, Unmanaged.passUnretained(self).toOpaque())
  }

  func close() {
    guard opened else { return }
    IOHIDDeviceRegisterInputReportCallback(device, buffer, 4096, nil, nil)
    IOHIDDeviceClose(device, 0)
    opened = false
  }

  private func received(_ bytes: [UInt8], reportID: UInt32) {
    guard opened else { return }
    var data = bytes
    if reportID != 0 && data.first != UInt8(truncatingIfNeeded: reportID) {
      data.insert(UInt8(truncatingIfNeeded: reportID), at: 0)
    }
    owner?.onReport?(id, data)
    if data.first == 1 && data.count == 10 && !initialized {
      initialized = true
      var feature = [UInt8](repeating: 0, count: 37)
      feature[0] = 2
      var length = feature.count
      let result = IOHIDDeviceGetReport(device, kIOHIDReportTypeFeature, 2, &feature, &length)
      if result != kIOReturnSuccess {
        owner?.onError?(
          "Could not request extended touch reports (\(result)). Reconnect the controller and retry."
        )
      }
    }
  }
}

private final class HIDReportBuffer: @unchecked Sendable {
  let bytes = UnsafeMutablePointer<UInt8>.allocate(capacity: 4096)
  deinit { bytes.deallocate() }
}
