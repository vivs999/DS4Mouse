import DS4Core
import DS4Platform
import Foundation

let help = """
  DS4Mouse — Bluetooth DualShock 4 touchpad mouse

    ds4mouse on | off | toggle | status | doctor
    ds4mouse mappings
    ds4mouse map <input> <action>
    ds4mouse set pointer-speed|scroll-speed <0.1–5.0>
  ds4mouse set pointer-acceleration <0.0–3.0>
    ds4mouse set scroll-direction natural|traditional
    ds4mouse config export <path> [--force]
    ds4mouse config import <path>
    ds4mouse config reset

  Add --json for machine-readable output.
  Examples:
    ds4mouse map tap left-click
    ds4mouse map two-finger-tap right-click
    ds4mouse map button-cross hold:left
    ds4mouse map two-finger-move scroll

  Inputs:
  \(Configuration.allInputs.joined(separator: ", "))

  Tap/button actions:
  \(Configuration.clickActions.joined(separator: ", "))
  Buttons also accept hold:left, hold:right, hold:middle, hold:back, hold:forward.
  Movement accepts pointer, scroll, or disabled.

  Exit codes: 0 success; 2 invalid command/configuration; 3 unavailable app;
  4 enable accepted but waiting for permission or controller readiness.
  """

func appURL() throws -> URL {
  let executable = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
    .resolvingSymlinksInPath()
  let bundle = executable.deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent()
  guard bundle.pathExtension == "app" else {
    throw AppError("Run the CLI bundled in DS4Mouse.app, or install it with scripts/install.sh.")
  }
  return bundle
}

func launch() throws {
  let process = Process()
  process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
  process.arguments = ["-g", try appURL().path]
  try process.run()
  process.waitUntilExit()
  guard process.terminationStatus == 0 else { throw AppError("Could not launch DS4Mouse.app.") }
  for _ in 0..<50 {
    if (try? LocalSocket.request(ControlRequest("status"))) != nil { return }
    Thread.sleep(forTimeInterval: 0.1)
  }
  throw AppError("DS4Mouse did not start within five seconds.")
}

let arguments = Array(CommandLine.arguments.dropFirst())
var exitCode: Int32 = 0
var failureCode: Int32 = 2
do {
  let command = try CLICommand.parse(arguments)
  if command.localOperation == "help" {
    print(help)
    exit(0)
  }
  var request = command.request
  if command.localOperation == "import", let file = command.file {
    let data = try Data(contentsOf: URL(fileURLWithPath: file))
    guard data.count <= 65536 else { throw AppError("Configuration exceeds 64 KiB.") }
    request.configuration = try Configuration.decode(data)
  }
  var response: ControlResponse
  failureCode = 3
  do { response = try LocalSocket.request(request) } catch LocalConnectionError.notRunning {
    if ["status", "doctor", "off"].contains(request.command) {
      response = ControlResponse(
        message: "DS4Mouse is not running.",
        status: ServiceStatus(running: false, message: "Not running"))
    } else {
      try launch()
      response = try LocalSocket.request(request)
    }
  }
  if command.localOperation == "export", let file = command.file,
    let config = response.configuration
  {
    let url = URL(fileURLWithPath: file)
    if FileManager.default.fileExists(atPath: url.path) && !command.overwrite {
      throw AppError("Export file already exists. Choose another path or use --force.")
    }
    try config.encoded().write(to: url, options: command.overwrite ? .atomic : .withoutOverwriting)
    response.message = "Exported configuration to \(url.path)."
  }
  if command.json {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    print(String(decoding: try encoder.encode(response), as: UTF8.self))
  } else if request.command == "mappings" && command.localOperation != "export",
    let config = response.configuration
  {
    for input in Configuration.allInputs {
      print("\(input): \(config.mappings[input] ?? "disabled")")
    }
  } else {
    print(response.message)
  }
  exitCode = response.exitCode
} catch {
  exitCode = failureCode
  if arguments.contains("--json") {
    let response = ControlResponse(
      ok: false, exitCode: exitCode, message: error.localizedDescription)
    if let data = try? JSONEncoder().encode(response) {
      print(String(decoding: data, as: UTF8.self))
    }
  } else {
    FileHandle.standardError.write(Data("ds4mouse: \(error.localizedDescription)\n".utf8))
  }
}
exit(exitCode)
