import AppKit
import Combine
import DS4Core
import DS4Platform
import SwiftUI

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
  let service = AppService()
  private var item: NSStatusItem!
  private var settings: NSWindow?
  private var subscription: AnyCancellable?
  private var signals: [DispatchSourceSignal] = []

  func applicationDidFinishLaunching(_ notification: Notification) {
    do { try service.start() } catch {
      if error.localizedDescription.contains("already running") {
        NSApp.terminate(nil)
        return
      }
      let alert = NSAlert()
      alert.messageText = "DS4Mouse could not start"
      alert.informativeText = error.localizedDescription
      alert.runModal()
      NSApp.terminate(nil)
      return
    }
    item = NSStatusBar.system.statusItem(withLength: 26)
    if let button = item.button {
      let image =
        Bundle.main.url(forResource: "MenuBarIcon", withExtension: "png")
        .flatMap { NSImage(contentsOf: $0) }
        ?? NSImage(named: NSImage.applicationIconName)
      if let image {
        image.size = NSSize(width: 22, height: 22)
        image.isTemplate = true
      }
      button.image = image
      button.imagePosition = .imageOnly
      button.imageScaling = .scaleProportionallyDown
      button.title = ""
    }
    subscription = service.$state.sink { [weak self] _ in self?.updateMenu() }
    updateMenu()
    for number in [SIGTERM, SIGINT] {
      signal(number, SIG_IGN)
      let source = DispatchSource.makeSignalSource(signal: number, queue: .main)
      source.setEventHandler { MainActor.assumeIsolated { NSApp.terminate(nil) } }
      source.resume()
      signals.append(source)
    }
  }
  func applicationWillTerminate(_ notification: Notification) { service.stop() }
  func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool
  {
    showSettings()
    return true
  }
  private func updateMenu() {
    guard item != nil else { return }
    item.button?.toolTip = "DS4Mouse: \(service.state.message)"
    item.button?.setAccessibilityLabel("DS4Mouse")
    let menu = NSMenu()
    let status = NSMenuItem(title: service.state.message, action: nil, keyEquivalent: "")
    status.isEnabled = false
    menu.addItem(status)
    let toggle = NSMenuItem(
      title: service.state.enabled ? "Disable mouse" : "Enable mouse",
      action: #selector(toggleMouse), keyEquivalent: "")
    toggle.target = self
    menu.addItem(toggle)
    menu.addItem(.separator())
    let settingsItem = NSMenuItem(
      title: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
    settingsItem.target = self
    menu.addItem(settingsItem)
    menu.addItem(
      NSMenuItem(
        title: "Quit DS4Mouse", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    item.menu = menu
  }
  @objc private func toggleMouse() { service.perform(ControlRequest("toggle")) }
  @objc func showSettings() {
    if settings == nil {
      let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 650, height: 640),
        styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered,
        defer: false)
      window.title = "DS4Mouse Settings"
      window.isReleasedWhenClosed = false
      window.contentView = NSHostingView(rootView: SettingsView(service: service))
      window.minSize = NSSize(width: 590, height: 500)
      window.center()
      settings = window
    }
    settings?.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
  }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
