import DS4Core
import DS4Platform
import Foundation

let hid = HIDController()
var reportCount = 0
var validCount = 0
var formats: Set<String> = []
hid.onDevices = { devices in print("Controllers: \(devices.map(\.name).joined(separator: ", "))") }
hid.onError = { print("Input error: \($0)") }
hid.onReport = { _, data in
  reportCount += 1
  let format = "id=\(data.first ?? 0) length=\(data.count)"
  if formats.insert(format).inserted { print("Report: \(format)") }
  do {
    let report = try ReportParser.parse(data)
    validCount += 1
    if report.samples.contains(where: { !$0.contacts.isEmpty }) && validCount % 50 == 0 {
      print("Touch contacts: \(report.samples.last?.contacts ?? [])")
    }
  } catch {
    if reportCount <= 3 { print(error.localizedDescription) }
  }
}
hid.start()
let duration = CommandLine.arguments.dropFirst().first.flatMap(Double.init) ?? 10
RunLoop.main.run(until: Date().addingTimeInterval(min(60, max(1, duration))))
hid.stop()
print("Reports received: \(reportCount); valid extended reports: \(validCount)")
