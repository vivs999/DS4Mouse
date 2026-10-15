import AppKit
import Combine
import DS4Core

@MainActor public final class AppService: ObservableObject {
  @Published public private(set) var configuration = Configuration.defaults
  @Published public private(set) var state = ServiceStatus()
  @Published public var uiError: String?
  private let store = ConfigurationStore()
  private let hid = HIDController()
  public let mouse = MouseOutput()
  private var pipeline = InputPipeline(configuration: .defaults)
  private var server: LocalServer?
  private var timer: Timer?
  private var observers: [NSObjectProtocol] = []
  private var enabled = false
  private var sleeping = false
  private var devices: [ControllerDevice] = []
  private var selected: String?
  private var excludedReconnectIDs: Set<String> = []
  private var lastReport: Double = 0
  private var validReports = 0
  private var failures = 0
  private var inputError: String?
  private var configError: String?
  private var wasReady = false
  private var running = false

  public init() {
    do { configuration = try store.load() } catch {
      configError =
        "Configuration could not be loaded: \(error.localizedDescription) Reset or import a valid configuration."
    }
    pipeline = InputPipeline(configuration: configuration)
    refresh()
  }
  public func start() throws {
    server = try LocalServer { [weak self] request, completion in
      Task { @MainActor in
        guard let self else {
          completion(ControlResponse(ok: false, exitCode: 3, message: "App is closing."))
          return
        }
        completion(self.handle(request))
      }
    }
    running = true
    hid.onDevices = { [weak self] in self?.changedDevices($0) }
    hid.onReport = { [weak self] in self?.received($1, from: $0) }
    hid.onError = { [weak self] error in
      self?.inputError = error
      self?.refresh()
    }
    hid.start()
    timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
      Task { @MainActor in self?.refresh() }
    }
    for (name, sleeping) in [
      (NSWorkspace.willSleepNotification, true), (NSWorkspace.didWakeNotification, false),
    ] {
      observers.append(
        NSWorkspace.shared.notificationCenter.addObserver(forName: name, object: nil, queue: .main)
        { [weak self] _ in
          Task { @MainActor in
            guard let self else { return }
            self.sleeping = sleeping
            self.lastReport = 0
            self.resetInput()
            self.refresh()
          }
        })
    }
  }
  public func stop() {
    running = false
    enabled = false
    resetInput()
    timer?.invalidate()
    timer = nil
    hid.stop()
    server?.stop()
    server = nil
    for observer in observers { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
    observers.removeAll()
  }
  private var ready: Bool {
    configError == nil && !sleeping && selected != nil && inputError == nil && mouse.permitted
      && ProcessInfo.processInfo.systemUptime - lastReport < 1
  }
  private func resetInput() {
    mouse.send(pipeline.releaseAll())
    mouse.releaseAll()
    pipeline = InputPipeline(configuration: configuration)
  }
  private func changedDevices(_ next: [ControllerDevice]) {
    devices = next
    if let selected, !devices.contains(where: { $0.id == selected }) {
      self.selected = nil
      excludedReconnectIDs = Set(devices.map(\.id))
      lastReport = 0
      resetInput()
    }
    if selected == nil {
      let candidates = devices.filter { !excludedReconnectIDs.contains($0.id) }
      if candidates.count == 1 {
        selected = candidates[0].id
        lastReport = 0
        resetInput()
      }
    }
    refresh()
  }
  private func received(_ data: [UInt8], from id: String) {
    guard id == selected, !sleeping, let reportID = data.first,
      reportID == 1 || (0x11...0x19).contains(reportID)
    else { return }
    do {
      let report = try ReportParser.parse(data)
      let now = ProcessInfo.processInfo.systemUptime
      if now - lastReport >= 1 { resetInput() }
      lastReport = now
      validReports += 1
      failures = 0
      inputError = nil
      if enabled && ready { mouse.send(pipeline.consume(report, at: lastReport)) }
    } catch {
      failures += 1
      if failures >= 5 || data.count == 10 {
        inputError = error.localizedDescription
        lastReport = 0
        resetInput()
      }
    }
  }
  private func refresh() {
    let currentReady = ready
    if wasReady && !currentReady { resetInput() }
    wasReady = currentReady
    let message: String
    if let configError {
      message = configError
    } else if !enabled {
      message = "Disabled"
    } else if sleeping {
      message = "Enabled — waiting for wake"
    } else if !mouse.permitted {
      message = "Enabled — Accessibility permission needed"
    } else if selected == nil {
      message = "Enabled — waiting for controller"
    } else if let inputError {
      message = "Enabled — \(inputError)"
    } else if !currentReady {
      message = "Enabled — waiting for touch reports"
    } else {
      message = "Enabled — controller mouse active"
    }
    state = ServiceStatus(
      enabled: enabled, ready: currentReady, permissionGranted: mouse.permitted,
      selectedDevice: selected, devices: devices, message: message, validReports: validReports)
  }
  public func apply(_ candidate: Configuration) throws {
    guard configError == nil else { throw AppError(configError!) }
    try store.save(candidate)
    resetInput()
    configuration = candidate
    pipeline = InputPipeline(configuration: candidate)
    refresh()
  }
  public func perform(_ request: ControlRequest) {
    let response = handle(request)
    uiError = response.exitCode == 2 || response.exitCode == 3 ? response.message : nil
  }
  public func handle(_ request: ControlRequest) -> ControlResponse {
    guard running else {
      return ControlResponse(ok: false, exitCode: 3, message: "DS4Mouse is closing.")
    }
    do {
      guard request.protocolVersion == 1 else {
        throw AppError("Unsupported control protocol version.")
      }
      let args = request.arguments
      switch request.command {
      case "on", "off", "toggle":
        guard args.isEmpty else { throw AppError("Unexpected arguments.") }
        if request.command != "off", let configError { throw AppError(configError) }
        resetInput()
        enabled = request.command == "toggle" ? !enabled : request.command == "on"
      case "map":
        guard args.count == 2 else { throw AppError("Expected an input and action.") }
        var candidate = configuration
        candidate.mappings[args[0]] = args[1]
        try apply(candidate)
      case "set":
        guard args.count == 2 else { throw AppError("Expected a setting and value.") }
        var candidate = configuration
        try candidate.set(args[0], to: args[1])
        try apply(candidate)
      case "replace":
        guard let candidate = request.configuration else {
          throw AppError("Missing configuration.")
        }
        try candidate.validate()
        if configError != nil { try store.resetPreservingPrevious() }
        try store.save(candidate)
        configError = nil
        resetInput()
        configuration = candidate
        pipeline = InputPipeline(configuration: candidate)
      case "reset":
        try store.resetPreservingPrevious()
        configError = nil
        resetInput()
        configuration = .defaults
        pipeline = InputPipeline(configuration: .defaults)
      case "select":
        guard args.count == 1, devices.contains(where: { $0.id == args[0] }) else {
          throw AppError("Controller is no longer connected.")
        }
        resetInput()
        selected = args[0]
        excludedReconnectIDs.removeAll()
        lastReport = 0
      case "status", "doctor", "mappings":
        guard args.isEmpty else { throw AppError("Unexpected arguments.") }
      default: throw AppError("Unknown command: \(request.command).")
      }
      refresh()
      let waiting = ["on", "toggle"].contains(request.command) && enabled && !ready
      return ControlResponse(
        exitCode: waiting ? 4 : 0, message: state.message, status: state,
        configuration: request.command == "mappings" || request.command == "doctor"
          ? configuration : nil)
    } catch {
      return ControlResponse(
        ok: false, exitCode: 2, message: error.localizedDescription, status: state)
    }
  }
}
