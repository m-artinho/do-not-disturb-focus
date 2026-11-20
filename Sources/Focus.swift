import AppKit

/// Runs the "DND On" / "DND Off" shortcuts — macOS has no public API to toggle Focus.
enum Shortcut {
    static let on = "DND On"
    static let off = "DND Off"

    /// Returns an error message, or nil on success.
    static func run(_ name: String) async -> String? {
        await withCheckedContinuation { cont in
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
            p.arguments = ["run", name]
            let err = Pipe()
            p.standardError = err
            p.standardOutput = FileHandle.nullDevice
            p.terminationHandler = { proc in
                let data = err.fileHandleForReading.readDataToEndOfFile()
                let msg = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if proc.terminationStatus == 0 {
                    cont.resume(returning: nil)
                } else {
                    cont.resume(returning: msg.isEmpty
                        ? "Shortcut “\(name)” failed. Is it installed in the Shortcuts app?"
                        : "“\(name)”: \(msg)")
                }
            }
            do { try p.run() } catch {
                cont.resume(returning: "Couldn't run shortcuts: \(error.localizedDescription)")
            }
        }
    }

    /// Blocking variant, used while the app is quitting.
    static func runSync(_ name: String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
        p.arguments = ["run", name]
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        try? p.run()
        p.waitUntilExit()
    }
}

@MainActor
final class FocusController: ObservableObject {
    @Published private(set) var endDate: Date?
    @Published private(set) var now = Date()
    @Published private(set) var busy = false
    @Published var error: String?
    /// Bumped every time the popover opens so the text field can grab focus.
    @Published var openCount = 0

    var onChange: (() -> Void)?

    private let key = "endDate"
    private var timer: Timer?

    var isActive: Bool { endDate != nil }
    var remaining: TimeInterval { max(0, (endDate ?? now).timeIntervalSince(now)) }

    init() {
        // Resume a session that survived an app restart (e.g. login item relaunch).
        endDate = UserDefaults.standard.object(forKey: key) as? Date

        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        t.tolerance = 0.3
        RunLoop.main.add(t, forMode: .common)
        timer = t

        // Wall-clock check after sleep, so an end time that passed while asleep is honoured at once.
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        tick()
    }

    func tick() {
        now = Date()
        if let end = endDate, now >= end, !busy {
            Task { await stop() }
        }
        onChange?()
    }

    func start(until end: Date) async {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        error = nil
        if let e = await Shortcut.run(Shortcut.on) {
            error = e
            return
        }
        set(end)
    }

    func stop() async {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        if let e = await Shortcut.run(Shortcut.off) { error = e } else { error = nil }
        set(nil)
    }

    /// Called on quit: never leave Do Not Disturb on with nothing around to turn it off.
    func stopBeforeQuit() {
        guard isActive else { return }
        Shortcut.runSync(Shortcut.off)
        set(nil)
    }

    private func set(_ date: Date?) {
        endDate = date
        UserDefaults.standard.set(date, forKey: key)
        now = Date()
        onChange?()
    }
}
