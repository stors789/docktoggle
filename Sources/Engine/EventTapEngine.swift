import CoreGraphics
import AppKit
import OSLog

final class EventTapEngine {
    static let shared = EventTapEngine()
    private let log = Logger(subsystem: "com.docktoggle", category: "EventTap")

    private var eventTap: CFMachPort?
    private var runLoop: CFRunLoop?
    private var runLoopSource: CFRunLoopSource?
    private(set) var isRunning = false

    private let lock = NSLock()
    private var _shouldSwallowNextMouseUp = false
    private var swallowTimer: Timer?

    private var shouldSwallowNextMouseUp: Bool {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _shouldSwallowNextMouseUp
        }
        set {
            lock.lock()
            _shouldSwallowNextMouseUp = newValue
            lock.unlock()
        }
    }

    private func setShouldSwallowNextMouseUp() {
        shouldSwallowNextMouseUp = true
        DispatchQueue.main.async { [weak self] in
            self?.swallowTimer?.invalidate()
            self?.swallowTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
                self?.shouldSwallowNextMouseUp = false
                DebugLog.shared.write("[TAP] swallow timeout cleared")
            }
        }
    }

    private init() {}

    func start() -> Bool {
        guard !isRunning else { return true }

        let mask: CGEventMask = CGEventMask(1 << CGEventType.leftMouseDown.rawValue) |
                                CGEventMask(1 << CGEventType.leftMouseUp.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { (proxy, type, event, userInfo) -> Unmanaged<CGEvent>? in
                let engine = Unmanaged<EventTapEngine>
                    .fromOpaque(userInfo!).takeUnretainedValue()
                return engine.handleEvent(type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            log.error("CGEvent.tapCreate returned nil")
            return false
        }

        eventTap = tap
        log.info("Event tap created (defaultTap)")

        let currentRunLoop = CFRunLoopGetCurrent()
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoop = currentRunLoop
        runLoopSource = source
        CFRunLoopAddSource(currentRunLoop, source, .defaultMode)
        CGEvent.tapEnable(tap: tap, enable: true)
        isRunning = true
        log.info("Event tap running on dedicated RunLoop")
        CFRunLoopRun()
        log.info("CFRunLoopRun returned")
        isRunning = false
        eventTap = nil
        runLoop = nil
        runLoopSource = nil
        return true
    }

    func stop() {
        guard let tap = eventTap else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        if let runLoop, let runLoopSource {
            CFRunLoopRemoveSource(runLoop, runLoopSource, .defaultMode)
            CFRunLoopStop(runLoop)
        }
        eventTap = nil
        runLoop = nil
        runLoopSource = nil
        isRunning = false
        log.info("Event tap stopped")
    }

    var isTapEnabled: Bool {
        guard let tap = eventTap else { return false }
        return CGEvent.tapIsEnabled(tap: tap)
    }

    private func isAppFullscreen(pid: pid_t) -> Bool {
        let appElement = AXUIElementCreateApplication(pid)
        var window: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, "AXFocusedWindow" as CFString, &window) == .success,
              let rawWindow = window else { return false }
        
        let win = rawWindow as! AXUIElement
        var fullscreen: CFTypeRef?
        if AXUIElementCopyAttributeValue(win, "AXFullScreen" as CFString, &fullscreen) == .success,
           let isFS = fullscreen as? Bool {
            return isFS
        }
        return false
    }

    private func requiredFlags(for name: String) -> CGEventFlags {
        switch name.lowercased() {
        case "option":
            return .maskAlternate
        case "command":
            return .maskCommand
        case "control":
            return .maskControl
        case "shift":
            return .maskShift
        default:
            return []
        }
    }

    private func handleEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Handle Event Tap auto-disable recovery
        if type == .tapDisabledByTimeout {
            log.warning("Event tap disabled by timeout, re-enabling...")
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return nil
        } else if type == .tapDisabledByUserInput {
            log.warning("Event tap disabled by user input (secure input active)")
            return nil
        }

        if type == .leftMouseUp {
            if shouldSwallowNextMouseUp {
                shouldSwallowNextMouseUp = false
                DebugLog.shared.write("[TAP] swallow mouseUp")
                return nil
            }
            return Unmanaged.passUnretained(event)
        }

        // type == .leftMouseDown
        
        // 1. Modifier Key Filter
        let rawModifier = UserDefaults.standard.string(forKey: "triggerModifier") ?? "None"
        let reqFlags = requiredFlags(for: rawModifier)
        let eventFlags = event.flags
        
        if reqFlags.isEmpty {
            // "None" modifier mode. If any standard modifier (Cmd, Option, Control, Shift) is pressed,
            // we pass through the event to preserve native OS shortcuts (e.g. Cmd+Click to open in Finder).
            let hasModifiers = eventFlags.contains(.maskAlternate) ||
                               eventFlags.contains(.maskCommand) ||
                               eventFlags.contains(.maskControl) ||
                               eventFlags.contains(.maskShift)
            if hasModifiers {
                return Unmanaged.passUnretained(event)
            }
        } else {
            // Specific modifier is required. If the event flags do not contain the required flags, pass through.
            if !eventFlags.contains(reqFlags) {
                return Unmanaged.passUnretained(event)
            }
        }

        // 2. Dock hotspot check
        let point = event.location
        guard DockInspector.shared.isPointInDockArea(point) else {
            return Unmanaged.passUnretained(event)
        }

        // Check if Dock is hidden/hiding
        if DockInspector.shared.isDockHidden() {
            return Unmanaged.passUnretained(event)
        }

        // 3. Multi-Space/Mission Control adaptation: get live frontmost application PID directly
        let liveFrontmostPID = NSWorkspace.shared.frontmostApplication?.processIdentifier ?? FrontmostTracker.shared.currentPID
        let capturedFrontmostPID = liveFrontmostPID
        
        // Cache lookup with direct identification fallback (solves magnification and sync issues)
        var targetPID = DockIconCache.shared.lookup(at: point)
        if targetPID == nil {
            let identified = DockInspector.shared.identifyApp(at: point)
            targetPID = identified.pid
            if let pid = targetPID {
                DebugLog.shared.write("[TAP] cache miss but direct identification succeeded: pid=\(pid)")
            }
        }

        guard let targetPID = targetPID else {
            return Unmanaged.passUnretained(event)
        }

        // 4. Resolve settings
        let rawMode = UserDefaults.standard.string(forKey: "behaviorMode") ?? "hide"
        var mode = BehaviorMode(rawValue: rawMode) ?? .hide

        // Stage Manager adaptation: override Hide to Minimize if Stage Manager is enabled
        let stageManagerEnabled = UserDefaults(suiteName: "com.apple.WindowManager")?.bool(forKey: "GloballyEnabled") ?? false
        if stageManagerEnabled && mode == .hide {
            DebugLog.shared.write("[TAP] Stage Manager is active: overriding behaviorMode hide -> minimize")
            mode = .minimize
        }

        // Resolve bundle IDs for multi-process matching
        let targetApp = NSRunningApplication(processIdentifier: targetPID)
        let frontmostApp = NSRunningApplication(processIdentifier: capturedFrontmostPID)
        let targetBundleID = targetApp?.bundleIdentifier
        let frontmostBundleID = frontmostApp?.bundleIdentifier
        let targetName = targetApp?.localizedName ?? "?"
        let frontmostName = frontmostApp?.localizedName ?? "?"

        DebugLog.shared.write("[TAP] mouseDown@(\(Int(point.x)),\(Int(point.y))) frontmost=\(capturedFrontmostPID)(\(frontmostName)) target=\(targetPID)(\(targetName)) mode=\(rawMode) stageManager=\(stageManagerEnabled)")

        // 5. Excluded applications check
        let excludedStr = UserDefaults.standard.string(forKey: "excludedBundleIDs") ?? "com.apple.finder"
        let excludedList = excludedStr
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        guard targetBundleID != "com.apple.dock",
              !excludedList.contains(targetBundleID ?? ""),
              targetPID != 0
        else {
            DebugLog.shared.write("[TAP] ignored excluded/protected target bundle=\(targetBundleID ?? "nil") pid=\(targetPID)")
            return Unmanaged.passUnretained(event)
        }

        // Debounce
        if ActionExecutor.shared.isRestoring(pid: targetPID) {
            DebugLog.shared.write("[TAP] debounce — pass through for PID \(targetPID)")
            return Unmanaged.passUnretained(event)
        }

        // Match by PID, bundle ID, or localized name (handles multi-process apps)
        let isSameApp = targetPID == capturedFrontmostPID ||
            (targetBundleID != nil && targetBundleID == frontmostBundleID) ||
            (targetApp?.localizedName != nil && targetApp?.localizedName == frontmostApp?.localizedName)

        if !isSameApp {
            DebugLog.shared.write("[TAP] mismatch: pid(\(targetPID)!=\(capturedFrontmostPID)) bundle(\(targetBundleID ?? "nil")!=\(frontmostBundleID ?? "nil")) name(\(targetName)!=\(frontmostName))")
        }

        if isSameApp {
            // Fullscreen check: don't toggle fullscreen applications (exiting fullscreen can be disruptive)
            let actionPID = capturedFrontmostPID
            if isAppFullscreen(pid: actionPID) {
                DebugLog.shared.write("[TAP] actionPID=\(actionPID) is fullscreen — passing through")
                return Unmanaged.passUnretained(event)
            }

            setShouldSwallowNextMouseUp()
            ActionExecutor.shared.markRestoring(pid: targetPID)
            DebugLog.shared.write("[TAP] SWALLOW + execute \(mode) on actionPID=\(actionPID) (cache target=\(targetPID))")
            DispatchQueue.main.async {
                ActionExecutor.shared.execute(targetPID: actionPID, mode: mode)
            }
            return nil
        }

        // Not frontmost → pass through
        ActionExecutor.shared.markRestoring(pid: targetPID)
        DebugLog.shared.write("[TAP] pass through (not frontmost) + debounce PID \(targetPID)")
        return Unmanaged.passUnretained(event)
    }
}
