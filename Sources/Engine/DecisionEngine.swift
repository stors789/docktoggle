import CoreGraphics
import Foundation
import OSLog

final class DecisionEngine {
    static let shared = DecisionEngine()
    private let log = Logger(subsystem: "com.docktoggle", category: "Decision")

    private init() {}

    func evaluate(location: CGPoint, capturedFrontmostPID: pid_t) {
        let inspector = DockInspector.shared

        if inspector.isDockHidden() {
            DebugLog.shared.write("[DECIDE] Dock hidden, abort")
            return
        }

        let (bundleID, targetPID) = inspector.identifyApp(at: location)

        DebugLog.shared.write("[DECIDE] identifyApp result: bundleID=\(bundleID ?? "nil"), targetPID=\(targetPID ?? 0), frontmostPID=\(capturedFrontmostPID)")

        guard let pid = targetPID else {
            log.notice("No target PID identified")
            return
        }

        guard pid == capturedFrontmostPID else {
            log.notice("PID mismatch: target=\(pid) frontmost=\(capturedFrontmostPID)")
            return
        }

        let rawMode = UserDefaults.standard.string(forKey: "behaviorMode") ?? "hide"
        let mode = BehaviorMode(rawValue: rawMode) ?? .hide

        DebugLog.shared.write("[DECIDE] Match! Executing \(rawMode) on PID \(pid)")
        ActionExecutor.shared.execute(targetPID: pid, mode: mode)
    }
}
