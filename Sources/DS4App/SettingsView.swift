import AppKit
import DS4Core
import DS4Platform
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
  @ObservedObject var service: AppService
  private let touchInputs = [
    "one-finger-move", "two-finger-move", "tap", "two-finger-tap", "touchpad-press",
  ]
  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack {
        VStack(alignment: .leading, spacing: 4) {
          Text("DS4Mouse").font(.largeTitle.bold())
          Text(service.state.message).font(.callout).foregroundStyle(.secondary)
        }
        Spacer()
        Toggle(
          "Mouse enabled",
          isOn: Binding(
            get: { service.state.enabled },
            set: { service.perform(ControlRequest($0 ? "on" : "off")) })
        ).toggleStyle(.switch)
      }
      if let error = service.uiError { Text(error).foregroundStyle(.red).textSelection(.enabled) }
      TabView {
        Form {
          Section("Connection") {
            if service.state.devices.isEmpty {
              Text("Connect your DualShock 4 in macOS Bluetooth settings.")
            } else {
              Picker(
                "Controller",
                selection: Binding(
                  get: { service.state.selectedDevice ?? "" },
                  set: { service.perform(ControlRequest("select", [$0])) })
              ) {
                Text("Choose controller").tag("")
                ForEach(service.state.devices, id: \.id) { Text($0.name).tag($0.id) }
              }
            }
            Text("Validated input reports: \(service.state.validReports)").font(.caption)
              .foregroundStyle(.secondary)
          }
          Section("Pointer and scrolling") {
            speed("Pointer speed", key: "pointer-speed", value: service.configuration.pointerSpeed)
            HStack {
              Text("Acceleration").frame(width: 100, alignment: .leading)
              Slider(
                value: Binding(
                  get: { service.configuration.pointerAcceleration },
                  set: {
                    service.perform(ControlRequest("set", ["pointer-acceleration", String($0)]))
                  }),
                in: 0...3, step: 0.1
              ).accessibilityLabel("Pointer acceleration")
              Text(
                service.configuration.pointerAcceleration == 0
                  ? "Off" : String(format: "%.1f", service.configuration.pointerAcceleration)
              )
              .monospacedDigit().frame(width: 45)
            }
            Text("Faster swipes travel farther. Set acceleration to 0 for constant sensitivity.")
              .font(.caption).foregroundStyle(.secondary)
            speed("Scroll speed", key: "scroll-speed", value: service.configuration.scrollSpeed)
            Picker(
              "Scroll direction",
              selection: Binding(
                get: { service.configuration.scrollDirection },
                set: { service.perform(ControlRequest("set", ["scroll-direction", $0])) })
            ) {
              Text("Natural").tag("natural")
              Text("Traditional").tag("traditional")
            }
          }
          if service.needsPermissionSettings {
            Section("Permissions") {
              if !service.state.permissionGranted {
                Text(
                  "Allow DS4Mouse in Privacy & Security → \(service.mouse.permissionSettingsName) to control the pointer."
                )
                Button("Open \(service.mouse.permissionSettingsName)") {
                  service.mouse.requestPermission()
                  if let url = URL(
                    string:
                      "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
                  ) {
                    NSWorkspace.shared.open(url)
                  }
                }
              }
              if service.needsInputMonitoringPermission {
                Text("Allow DS4Mouse in Input Monitoring to read controller input.")
                Button("Open Input Monitoring settings") {
                  service.openInputMonitoringSettings()
                }
              }
              Text("After changing permissions, quit and reopen DS4Mouse if needed.")
                .font(.caption).foregroundStyle(.secondary)
            }
          }
        }.formStyle(.grouped).tabItem { Text("General") }
        Form {
          Section("Touchpad") {
            ForEach(touchInputs, id: \.self) { mapping($0) }
          }
          Section("Controller buttons") {
            ForEach(Configuration.buttonInputs.filter { $0 != "touchpad-press" }, id: \.self) {
              mapping($0)
            }
          }
        }.formStyle(.grouped).tabItem { Text("Mappings") }
      }
      HStack {
        Button("Import…", action: importConfig)
        Button("Export…", action: exportConfig)
        Spacer()
        Button("Restore defaults…", action: restoreDefaults)
      }
      Text("Changes save automatically. Mouse control starts disabled each time the app launches.")
        .font(.caption).foregroundStyle(.secondary)
    }
    .padding(20)
  }
  private func restoreDefaults() {
    let alert = NSAlert()
    alert.messageText = "Restore default mouse mappings and speeds?"
    alert.informativeText = "Your previous configuration will be backed up."
    alert.addButton(withTitle: "Restore defaults")
    alert.addButton(withTitle: "Cancel")
    if alert.runModal() == .alertFirstButtonReturn { service.perform(ControlRequest("reset")) }
  }
  private func title(_ value: String) -> String {
    value.replacingOccurrences(of: "button-", with: "").replacingOccurrences(of: "-", with: " ")
      .replacingOccurrences(of: "hold:", with: "Hold ").capitalized
  }
  private func mapping(_ input: String) -> some View {
    Picker(
      title(input),
      selection: Binding(
        get: { service.configuration.mappings[input] ?? "disabled" },
        set: { service.perform(ControlRequest("map", [input, $0])) })
    ) {
      ForEach(Configuration.actions(for: input), id: \.self) { Text(title($0)).tag($0) }
    }.accessibilityLabel(title(input))
  }
  private func speed(_ label: String, key: String, value: Double) -> some View {
    HStack {
      Text(label).frame(width: 100, alignment: .leading)
      Slider(
        value: Binding(
          get: {
            key == "pointer-speed"
              ? service.configuration.pointerSpeed : service.configuration.scrollSpeed
          },
          set: { service.perform(ControlRequest("set", [key, String($0)])) }), in: 0.1...5,
        step: 0.1
      )
      .accessibilityLabel(label)
      Text(String(format: "%.1f×", value)).monospacedDigit().frame(width: 45)
    }
  }
  private func importConfig() {
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.json]
    panel.allowsMultipleSelection = false
    guard panel.runModal() == .OK, let url = panel.url else { return }
    do {
      let data = try Data(contentsOf: url)
      guard data.count <= 65536 else { throw AppError("Configuration exceeds 64 KiB.") }
      service.perform(ControlRequest("replace", configuration: try Configuration.decode(data)))
    } catch { service.uiError = error.localizedDescription }
  }
  private func exportConfig() {
    let panel = NSSavePanel()
    panel.allowedContentTypes = [.json]
    panel.nameFieldStringValue = "ds4mouse-config.json"
    guard panel.runModal() == .OK, let url = panel.url else { return }
    do { try service.configuration.encoded().write(to: url, options: .atomic) } catch {
      service.uiError = error.localizedDescription
    }
  }
}
