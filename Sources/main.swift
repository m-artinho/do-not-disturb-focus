import AppKit
import SwiftUI
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let controller = FocusController()
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private var lastTitle = "\u{0}"
    private var lastActive: Bool?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(togglePopover)
            button.imagePosition = .imageLeading
            button.toolTip = "Do Not Disturb timer"
        }

        let hosting = NSHostingController(rootView: PanelView(controller: controller) { [weak self] in
            self?.popover.performClose(nil)
        })
        hosting.sizingOptions = [.preferredContentSize]
        popover.contentViewController = hosting
        popover.behavior = .transient
        popover.animates = false

        controller.onChange = { [weak self] in self?.refreshButton() }
        refreshButton()
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller.stopBeforeQuit()
    }

    private func refreshButton() {
        guard let button = statusItem?.button else { return }
        let active = controller.isActive
        if active != lastActive {
            let image = NSImage(systemSymbolName: active ? "moon.zzz.fill" : "moon.zzz",
                                accessibilityDescription: "Do Not Disturb")
            image?.isTemplate = true
            button.image = image
            lastActive = active
        }
        let title = active ? " " + Fmt.duration(controller.remaining) : ""
        if title != lastTitle {
            button.title = title
            lastTitle = title
        }
    }

    /// Opening the app again (Spotlight, Finder, `open`) shows the panel.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showPopover()
        return false
    }

    @objc private func togglePopover() {
        if popover.isShown { popover.performClose(nil) } else { showPopover() }
    }

    private func showPopover() {
        guard let button = statusItem?.button, !popover.isShown else { return }
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
        controller.openCount += 1
    }
}

// `FocusUntil --launch-at-login on|off` registers the app as a login item and exits.
if let i = CommandLine.arguments.firstIndex(of: "--launch-at-login") {
    let on = CommandLine.arguments.dropFirst(i + 1).first != "off"
    do {
        if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
    } catch {
        print("error: \(error.localizedDescription)")
    }
    let status = SMAppService.mainApp.status
    print(["notRegistered", "enabled", "requiresApproval", "notFound"][min(status.rawValue, 3)])
    exit(0)
}

// Single instance: if a copy is already running (e.g. started by the login item),
// ask it to show its panel and quit. Uses exit() rather than terminate so this copy
// never runs its quit handler, which would turn the other copy's Do Not Disturb off.
let bundleID = Bundle.main.bundleIdentifier ?? "local.focusuntil"
if let other = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
    .first(where: { $0.processIdentifier != getpid() }) {
    if let url = other.bundleURL { NSWorkspace.shared.open(url) }
    exit(0)
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
