import SwiftUI
import AppKit

struct SettingsView: View {
    @ObservedObject var configStore = ConfigStore.shared
    @ObservedObject var permissionsManager = PermissionsManager.shared
    @ObservedObject var appController = AppController.shared

    @State private var diagnostics = ""
    
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    var body: some View {
        ScrollView {
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

            Toggle("Launch at Login", isOn: Binding(
                get: { configStore.launchAtLogin },
                set: { appController.setLaunchAtLogin($0) }
            ))

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Trigger Shortcut")
                    .font(.headline)

                Picker("Modifier Key", selection: $configStore.triggerModifier) {
                    Text("Click (None)").tag("None")
                    Text("Option + Click").tag("Option")
                    Text("Command + Click").tag("Command")
                    Text("Control + Click").tag("Control")
                    Text("Shift + Click").tag("Shift")
                }
                .pickerStyle(.radioGroup)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Excluded Applications")
                    .font(.headline)
                
                Text("Comma-separated bundle IDs of apps that should not be toggled:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                TextField("e.g. com.apple.finder, com.apple.mail", text: $configStore.excludedBundleIDs)
                    .textFieldStyle(.roundedBorder)
            }

            Divider()

            PermissionsGateView()

            Divider()

            HStack {
                Text("Status: \(appController.statusMessage)")
                    .foregroundColor(appController.isEngineRunning ? .green : .red)
                Spacer()
                Button("Refresh Log") {
                    diagnostics = loadLog()
                }
                Button("Clear") {
                    DebugLog.shared.clear()
                    diagnostics = loadLog()
                }
                Button("Open") {
                    NSWorkspace.shared.activateFileViewerSelecting([DebugLog.shared.url])
                }
            }

            if !diagnostics.isEmpty {
                Text(diagnostics)
                    .font(.system(.caption, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(Color(NSColor.textBackgroundColor).opacity(0.5))
                    .cornerRadius(4)
            }

            Divider()

            HStack {
                Text("Version \(appVersion)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button("Quit DockToggle") {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
        .padding(20)
        }
        .frame(minWidth: 520, idealWidth: 520, minHeight: 520, maxHeight: 800)
        .onAppear {
            permissionsManager.checkPermissions()
            configStore.updateLaunchAtLoginStatus()
            diagnostics = loadLog()
        }
    }

    private func loadLog() -> String {
        DebugLog.shared.recentLines()
    }
}
