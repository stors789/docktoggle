import ApplicationServices
import AppKit

@MainActor
final class PermissionsManager: ObservableObject {
    static let shared = PermissionsManager()

    @Published var accessibilityGranted = false
    @Published var inputMonitoringGranted = false

    var allGranted: Bool { accessibilityGranted && inputMonitoringGranted }

    private init() {
        checkPermissions()
    }

    func checkPermissions() {
        accessibilityGranted = AXIsProcessTrusted()
        inputMonitoringGranted = CGPreflightListenEventAccess()
    }

    func requestAccessibility() {
        NSWorkspace.shared.open(
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        )
        NSApp.activate(ignoringOtherApps: true)
    }

    func requestInputMonitoring() {
        CGRequestListenEventAccess()
        NSWorkspace.shared.open(
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_InputMonitoring")!
        )
        NSApp.activate(ignoringOtherApps: true)
    }

    func pollForChanges() {
        let oldAccessibility = accessibilityGranted
        let oldInput = inputMonitoringGranted
        checkPermissions()
        if accessibilityGranted != oldAccessibility || inputMonitoringGranted != oldInput {
            AppController.shared.onPermissionsChanged()
        }
    }
}
