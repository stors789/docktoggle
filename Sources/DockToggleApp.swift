import SwiftUI
import AppKit
import ServiceManagement
import OSLog

let appLog = Logger(subsystem: "com.docktoggle", category: "App")

@MainActor
final class AppController: ObservableObject {
    static let shared = AppController()

    @Published var isEngineRunning = false
    @Published var showPermissionsWarning = false
    @Published var statusMessage = ""

    private var monitorTimer: Timer?
    private var cacheRefreshTimer: Timer?
    private var engineThread: Thread?

    private init() {}

    func startIfPermitted() {
        DebugLog.shared.write("[APP] startIfPermitted called")
        PermissionsManager.shared.checkPermissions()
        DebugLog.shared.write("[APP] permissions: ax=\(PermissionsManager.shared.accessibilityGranted) input=\(PermissionsManager.shared.inputMonitoringGranted)")

        if PermissionsManager.shared.allGranted {
            startEngine()
        } else {
            showPermissionsWarning = true
            statusMessage = "Permissions needed"
            showSettings()
        }
    }

    func startEngine() {
        guard !isEngineRunning else { return }

        _ = FrontmostTracker.shared
        _ = DockInspector.shared

        guard DockInspector.shared.resolve() else {
            statusMessage = "Dock not found"
            appLog.error("Failed to resolve Dock")
            return
        }

        guard let frame = DockInspector.shared.cachedGlobalDockFrame else {
            statusMessage = "Dock frame unavailable"
            appLog.error("Dock frame is nil after resolve")
            return
        }

        appLog.info("Dock frame: \(String(describing: frame))")

        engineThread = Thread {
            let ok = EventTapEngine.shared.start()
            appLog.info("EventTapEngine.start() returned \(ok)")
            DispatchQueue.main.async { [weak self] in
                self?.isEngineRunning = false
                self?.statusMessage = "Event tap stopped"
            }
        }
        engineThread?.name = "com.docktoggle.eventtap"
        engineThread?.start()

        Thread.sleep(forTimeInterval: 0.05)

        guard EventTapEngine.shared.isTapEnabled else {
            statusMessage = "Tap creation failed"
            appLog.error("Event tap created but not enabled — check permissions")
            return
        }

        isEngineRunning = true
        statusMessage = "Running"

        DockIconCache.shared.refresh()
        cacheRefreshTimer = Timer.scheduledTimer(
            withTimeInterval: 1.0,
            repeats: true
        ) { _ in
            DockIconCache.shared.refresh()
        }

        monitorTimer = Timer.scheduledTimer(
            withTimeInterval: 3.0,
            repeats: true
        ) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self else { return }
                if self.isEngineRunning && !EventTapEngine.shared.isTapEnabled {
                    self.isEngineRunning = false
                    self.statusMessage = "Event tap disabled"
                    self.showPermissionsWarning = true
                }
                PermissionsManager.shared.checkPermissions()

                if PermissionsManager.shared.allGranted && !self.isEngineRunning {
                    self.startEngine()
                }
            }
        }
    }

    func onPermissionsChanged() {
        if PermissionsManager.shared.allGranted && !isEngineRunning {
            startEngine()
            showPermissionsWarning = false
        }
    }

    func showSettings() {
        SettingsWindowManager.shared.show()
    }

    func stop() {
        monitorTimer?.invalidate()
        monitorTimer = nil
        cacheRefreshTimer?.invalidate()
        cacheRefreshTimer = nil
        EventTapEngine.shared.stop()
        engineThread = nil
        isEngineRunning = false
        statusMessage = "Stopped"
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        DispatchQueue.main.async {
            AppController.shared.startIfPermitted()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        AppController.shared.stop()
    }
}

@main
struct DockToggleApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @ObservedObject var appController = AppController.shared
    @AppStorage("behaviorMode") private var behaviorMode: BehaviorMode = .hide

    var body: some Scene {
        MenuBarExtra("DockToggle", systemImage: "dock.rectangle") {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("DockToggle")
                        .font(.headline)
                    Spacer()
                    Circle()
                        .fill(appController.isEngineRunning ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    Text(appController.statusMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Divider()

                Picker("Mode", selection: $behaviorMode) {
                    ForEach(BehaviorMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.inline)

                Toggle("Launch at Login", isOn: Binding(
                    get: { ConfigStore.shared.launchAtLogin },
                    set: { newValue in
                        ConfigStore.shared.launchAtLogin = newValue
                        if newValue {
                            try? SMAppService.mainApp.register()
                        } else {
                            try? SMAppService.mainApp.unregister()
                        }
                    }
                ))

                Divider()

                if appController.showPermissionsWarning {
                    Button("Permissions Needed") {
                        appController.showSettings()
                    }
                    .foregroundColor(.red)
                }

                Button("Open Settings...") {
                    appController.showSettings()
                }

                Divider()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(minWidth: 260)
        }
    }
}
