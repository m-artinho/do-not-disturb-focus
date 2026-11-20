import SwiftUI
import ServiceManagement

enum Mode: String {
    case minutes, until
}

struct PanelView: View {
    @ObservedObject var controller: FocusController
    var close: () -> Void

    @AppStorage("mode") private var mode: Mode = .minutes
    @State private var input = ""
    @State private var confirming = false
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @FocusState private var fieldFocused: Bool

    /// Longer than this asks for confirmation (catches typos like "2:30" vs "12:30").
    private let confirmAbove: TimeInterval = 90 * 60

    private var target: Date? {
        let now = controller.now
        switch mode {
        case .minutes:
            guard let m = Parse.minutes(input), m > 0, m <= 7 * 24 * 60 else { return nil }
            return now.addingTimeInterval(TimeInterval(m) * 60)
        case .until:
            return Parse.until(input, now: now)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if let end = controller.endDate { activeCard(end) }

            Picker("", selection: $mode) {
                Text("For").tag(Mode.minutes)
                Text("Until").tag(Mode.until)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            HStack(spacing: 8) {
                TextField(mode == .minutes ? "25" : "14:30 or 2:30pm", text: $input)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 15))
                    .focused($fieldFocused)
                if mode == .minutes {
                    Text("min").foregroundStyle(.secondary)
                }
            }

            hint

            if confirming, let t = target {
                confirmCard(t)
            } else {
                Button(action: submit) {
                    Text(controller.isActive ? "Change end time" : "Turn on Do Not Disturb")
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .disabled(target == nil || controller.busy)
            }

            if let e = controller.error {
                Text(e)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            HStack {
                Toggle("Launch at login", isOn: Binding(
                    get: { launchAtLogin },
                    set: setLaunchAtLogin
                ))
                .toggleStyle(.checkbox)
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
                    .buttonStyle(.borderless)
            }
            .font(.caption)
        }
        .padding(14)
        .frame(width: 290)
        .onChange(of: input) { _, _ in confirming = false }
        .onChange(of: mode) { _, _ in confirming = false; input = "" }
        .onChange(of: controller.openCount) { _, _ in
            confirming = false
            fieldFocused = true
        }
        .onAppear { fieldFocused = true }
    }

    // MARK: pieces

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: controller.isActive ? "moon.zzz.fill" : "moon.zzz")
                .foregroundStyle(controller.isActive ? Color.indigo : Color.secondary)
            Text("Do Not Disturb").font(.headline)
            Spacer()
            if controller.busy { ProgressView().controlSize(.small) }
        }
    }

    private func activeCard(_ end: Date) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("On until \(Fmt.end(end, now: controller.now))")
                    .font(.subheadline.weight(.semibold))
                Text("\(Fmt.duration(controller.remaining)) left")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Spacer()
            Button("Turn off") { Task { await controller.stop() } }
                .disabled(controller.busy)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.indigo.opacity(0.14)))
    }

    @ViewBuilder private var hint: some View {
        if input.trimmingCharacters(in: .whitespaces).isEmpty {
            Text(mode == .minutes ? "How many minutes? e.g. 25, 90, 1h30"
                                  : "e.g. 14:30, 23h, 2:30pm, 9am")
                .font(.caption).foregroundStyle(.secondary)
        } else if let t = target {
            Text("Until \(Fmt.end(t, now: controller.now)) · \(Fmt.duration(t.timeIntervalSince(controller.now)))")
                .font(.caption).foregroundStyle(.secondary).monospacedDigit()
        } else {
            Text(mode == .minutes ? "Type a number of minutes" : "Couldn't read that time")
                .font(.caption).foregroundStyle(.red)
        }
    }

    private func confirmCard(_ t: Date) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                Text("That's **\(Fmt.duration(t.timeIntervalSince(controller.now)))**, until \(Fmt.end(t, now: controller.now)). Is that right?")
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            }
            .font(.callout)
            HStack {
                Button("Cancel") { confirming = false; fieldFocused = true }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Yes, turn on", action: begin)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.orange.opacity(0.12)))
    }

    // MARK: actions

    private func submit() {
        guard let t = target, !controller.busy else { return }
        if t.timeIntervalSince(controller.now) > confirmAbove {
            confirming = true
        } else {
            begin()
        }
    }

    private func begin() {
        // Recompute so "for N minutes" counts from the moment it actually starts.
        guard let t = target else { return }
        confirming = false
        Task {
            await controller.start(until: t)
            if controller.error == nil {
                input = ""
                close()
            }
        }
    }

    private func setLaunchAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            controller.error = "Launch at login: \(error.localizedDescription)"
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
        if on && SMAppService.mainApp.status == .requiresApproval {
            controller.error = "Approve it in System Settings › General › Login Items."
            SMAppService.openSystemSettingsLoginItems()
        }
    }
}
