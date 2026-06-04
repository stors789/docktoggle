import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @ObservedObject var configStore = ConfigStore.shared
    @ObservedObject var permissionsManager = PermissionsManager.shared
    @ObservedObject var appController = AppController.shared

    @State private var launchAtLogin: Bool
    @State private var diagnostics = ""

    init() {
        _launchAtLogin = State(initialValue: ConfigStore.shared.launchAtLogin)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Behavior Mode")
                .font(.headline)

            Picker("Mode", selection: $configStore.behaviorMode) {
                ForEach(BehaviorMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.radioGroup)

            Divider()

            Toggle("Launch at Login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, newValue in
                    configStore.launchAtLogin = newValue
                    if newValue {
                        try? SMAppService.mainApp.register()
                    } else {
                        try? SMAppService.mainApp.unregister()
                    }
                }

            Divider()

            PermissionsGateView()

            Divider()

            HStack {
                Text("Status: \(appController.isEngineRunning ? "Running" : "Stopped")")
                    .foregroundColor(appController.isEngineRunning ? .green : .red)
                Spacer()
                Button("Refresh Log") {
                    diagnostics = loadLog()
                }
            }

            if !diagnostics.isEmpty {
                ScrollView {
                    Text(diagnostics)
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 200)
            }

            Divider()

            HStack {
                Text("Version 1.0.0")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button("Quit DockToggle") {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
        .padding(20)
        .frame(width: 360)
        .onAppear {
            diagnostics = loadLog()
        }
    }

    private func loadLog() -> String {
        guard let content = try? String(contentsOfFile: "/tmp/docktoggle.log", encoding: .utf8) else {
            return "Log file not found at /tmp/docktoggle.log\n\nClick 'Refresh Log' after clicking some Dock icons."
        }
        let lines = content.components(separatedBy: "\n")
        let tail = lines.suffix(30)
        return tail.joined(separator: "\n")
    }
}
