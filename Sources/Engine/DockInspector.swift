import ApplicationServices
import AppKit
import CoreGraphics
import OSLog

final class DockInspector {
    static let shared = DockInspector()
    private let log = Logger(subsystem: "com.docktoggle", category: "DockInspector")

    private var dockPID: pid_t = 0
    private var dockAppElement: AXUIElement?

    private var _cachedFrame: CGRect?
    private let frameQueue = DispatchQueue(
        label: "com.docktoggle.dockframe",
        attributes: .concurrent
    )

    var cachedGlobalDockFrame: CGRect? {
        frameQueue.sync { _cachedFrame }
    }

    private init() {}

    @discardableResult
    func resolve() -> Bool {
        let docks = NSRunningApplication.runningApplications(
            withBundleIdentifier: "com.apple.dock"
        )
        guard let dock = docks.first else {
            log.error("Dock process not found")
            return false
        }
        dockPID = dock.processIdentifier
        dockAppElement = AXUIElementCreateApplication(dockPID)
        log.info("Dock resolved: PID=\(self.dockPID)")

        Thread.sleep(forTimeInterval: 0.05)
        refreshFrame()
        return true
    }

    func refreshFrame() {
        guard let element = dockAppElement else {
            log.warning("refreshFrame: no dockAppElement")
            return
        }

        // Strategy 1: direct AXFrame on Dock application
        if let rect = axFrame(of: element), !rect.isEmpty {
            frameQueue.async(flags: .barrier) { self._cachedFrame = rect }
            log.info("Dock frame (direct): \(String(describing: rect))")
            return
        }

        // Strategy 2: AXPosition + AXSize
        if let rect = axPositionAndSize(of: element), !rect.isEmpty {
            frameQueue.async(flags: .barrier) { self._cachedFrame = rect }
            log.info("Dock frame (pos+size): \(String(describing: rect))")
            return
        }

        // Strategy 3: first child AXList element
        var children: CFTypeRef?
        if AXUIElementCopyAttributeValue(element,
                "AXChildren" as CFString, &children) == .success,
           let childrenArray = children as? [AXUIElement],
           let firstChild = childrenArray.first {
            if let rect = axFrame(of: firstChild), !rect.isEmpty {
                frameQueue.async(flags: .barrier) { self._cachedFrame = rect }
                log.info("Dock frame (child): \(String(describing: rect))")
                return
            }
            if let rect = axPositionAndSize(of: firstChild), !rect.isEmpty {
                frameQueue.async(flags: .barrier) { self._cachedFrame = rect }
                log.info("Dock frame (child pos+size): \(String(describing: rect))")
                return
            }
        }

        // Strategy 4: compute from screen geometry (all Dock positions)
        if let screen = NSScreen.main {
            let sf = screen.frame
            let vf = screen.visibleFrame

            let bottomH = sf.maxY - vf.maxY
            let leftW = vf.minX - sf.minX
            let rightW = sf.maxX - vf.maxX
            let topH = vf.minY - sf.minY

            var dockRect: CGRect?

            if bottomH > 0 {
                dockRect = CGRect(x: sf.origin.x, y: sf.origin.y, width: sf.width, height: bottomH)
            } else if leftW > 0 {
                dockRect = CGRect(x: sf.origin.x, y: sf.origin.y, width: leftW, height: sf.height)
            } else if rightW > 0 {
                dockRect = CGRect(x: vf.maxX, y: sf.origin.y, width: rightW, height: sf.height)
            } else if topH > 0 {
                dockRect = CGRect(x: sf.origin.x, y: vf.maxY, width: sf.width, height: topH)
            }

            if let dockRect, !dockRect.isEmpty {
                frameQueue.async(flags: .barrier) { self._cachedFrame = dockRect }
                log.info("Dock frame (screen calc): \(String(describing: dockRect))")
                DebugLog.shared.write("[DOCK] screen calc: sf=\(sf) vf=\(vf) -> dock=\(dockRect)")
                return
            }
        }

        log.error("All Dock frame resolution strategies failed")
    }

    private func axFrame(of element: AXUIElement) -> CGRect? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element,
                "AXFrame" as CFString, &value) == .success,
              let axValue = value as! AXValue?,
              AXValueGetType(axValue) == .cgRect
        else { return nil }
        var rect = CGRect.zero
        AXValueGetValue(axValue, .cgRect, &rect)
        return rect
    }

    private func axPositionAndSize(of element: AXUIElement) -> CGRect? {
        var posValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element,
                "AXPosition" as CFString, &posValue) == .success,
              let posAX = posValue as! AXValue?,
              AXValueGetType(posAX) == .cgPoint,
              AXUIElementCopyAttributeValue(element,
                "AXSize" as CFString, &sizeValue) == .success,
              let sizeAX = sizeValue as! AXValue?,
              AXValueGetType(sizeAX) == .cgSize
        else { return nil }

        var point = CGPoint.zero
        var size = CGSize.zero
        AXValueGetValue(posAX, .cgPoint, &point)
        AXValueGetValue(sizeAX, .cgSize, &size)
        return CGRect(origin: point, size: size)
    }

    func isDockHidden() -> Bool {
        guard let element = dockAppElement else { return false }
        var hidden: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element,
            "AXHidden" as CFString,
            &hidden
        ) == .success,
              let val = hidden as? Bool
        else { return false }
        return val
    }

    func identifyApp(at point: CGPoint) -> (bundleID: String?, pid: pid_t?) {
        guard let appElement = dockAppElement else {
            DebugLog.shared.write("[DOCK] no dockAppElement")
            return (nil, nil)
        }

        var hit: AXUIElement?
        let status = AXUIElementCopyElementAtPosition(
            appElement,
            Float(point.x),
            Float(point.y),
            &hit
        )
        guard status == .success, let hitElement = hit else {
            DebugLog.shared.write("[DOCK] AX hit test FAILED at (\(point.x), \(point.y)): status=\(status.rawValue)")
            return (nil, nil)
        }

        var pid: pid_t = 0
        AXUIElementGetPid(hitElement, &pid)
        DebugLog.shared.write("[DOCK] AX hit pid=\(pid), dockPID=\(self.dockPID)")

        guard pid == dockPID else {
            return (nil, nil)
        }

        guard let dockItem = findParentDockItem(from: hitElement) else {
            DebugLog.shared.write("[DOCK] No DockItem in parent chain")
            return (nil, nil)
        }

        let result = extractApp(from: dockItem)
        DebugLog.shared.write("[DOCK] extractApp: bundleID=\(result.bundleID ?? "nil"), pid=\(result.pid ?? 0)")
        return result
    }

    private func findParentDockItem(from element: AXUIElement) -> AXUIElement? {
        var current = element
        for i in 0..<10 {
            var role: CFTypeRef?
            AXUIElementCopyAttributeValue(
                current,
                "AXRole" as CFString,
                &role
            )
            let roleStr = (role as? String) ?? ""
            DebugLog.shared.write("[DOCK] depth=\(i) role=\(roleStr)")

            if isDockItemRole(roleStr) {
                return current
            }

            var parentValue: CFTypeRef?
            guard AXUIElementCopyAttributeValue(
                current,
                "AXParent" as CFString,
                &parentValue
            ) == .success,
                  let parent = parentValue as! AXUIElement?
            else { return nil }
            current = parent
        }
        return nil
    }

    private func isDockItemRole(_ role: String) -> Bool {
        role.lowercased().contains("dockitem")
    }

    private func extractApp(from dockItem: AXUIElement) -> (bundleID: String?, pid: pid_t?) {
        // Strategy A: AXURL
        var axURL: CFTypeRef?
        if AXUIElementCopyAttributeValue(
            dockItem,
            "AXURL" as CFString,
            &axURL
        ) == .success,
           let urlStr = axURL as? String,
           let url = URL(string: urlStr),
           let bundle = Bundle(url: url),
           let bundleID = bundle.bundleIdentifier
        {
            let pid = NSWorkspace.shared.runningApplications
                .first(where: { $0.bundleIdentifier == bundleID })?
                .processIdentifier
            log.info("extractApp (URL): bundleID=\(bundleID), pid=\(pid ?? 0)")
            return (bundleID, pid)
        }

        // Strategy B: AXTitle fallback (exact match)
        let axTitleVal = getAXTitle(from: dockItem)
        if let title = axTitleVal {
            if let pid = pidByTitle(title) {
                log.info("extractApp (title): \(title), pid=\(pid)")
                return (nil, pid)
            }
        }

        // Strategy C: AXURL path → parse app name from path and match
        if let urlStr = axURL as? String,
           let pid = pidByParsingAXURL(urlStr) {
            log.info("extractApp (url-path): pid=\(pid)")
            return (nil, pid)
        }

        // Strategy D: Fuzzy AXTitle matching
        if let title = axTitleVal,
           let pid = pidByTitleFuzzy(title) {
            log.info("extractApp (title-fuzzy): \(title), pid=\(pid)")
            return (nil, pid)
        }

        // Strategy E: Sub-element PID
        if let pid = pidFromSubElements(of: dockItem) {
            log.info("extractApp (sub-element): pid=\(pid)")
            return (nil, pid)
        }

        log.warning("extractApp: no PID found via any strategy")
        return (nil, nil)
    }

    // MARK: - PID extraction helpers

    private func getAXTitle(from element: AXUIElement) -> String? {
        var axTitle: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, "AXTitle" as CFString, &axTitle) == .success,
              let title = axTitle as? String
        else { return nil }
        return title
    }

    private func pidByTitle(_ title: String) -> pid_t? {
        return NSWorkspace.shared.runningApplications
            .first(where: { $0.localizedName == title })?
            .processIdentifier
    }

    private func pidByParsingAXURL(_ urlStr: String) -> pid_t? {
        guard let url = URL(string: urlStr) else { return nil }
        var path = url.path

        if path.hasSuffix("/") { path.removeLast() }

        let appName: String
        if path.hasSuffix(".app") {
            appName = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
        } else {
            appName = URL(fileURLWithPath: path).lastPathComponent
        }

        return NSWorkspace.shared.runningApplications
            .first(where: { $0.localizedName == appName })?
            .processIdentifier
    }

    private func pidByTitleFuzzy(_ title: String) -> pid_t? {
        let runningApps = NSWorkspace.shared.runningApplications

        if let app = runningApps.first(where: {
            $0.localizedName?.replacingOccurrences(of: ".app", with: "") == title
        }) {
            return app.processIdentifier
        }

        if let app = runningApps.first(where: {
            $0.localizedName?.caseInsensitiveCompare(title) == .orderedSame
        }) {
            return app.processIdentifier
        }

        if let app = runningApps.first(where: {
            guard let name = $0.localizedName else { return false }
            return name.contains(title) || title.contains(name)
        }) {
            return app.processIdentifier
        }

        return nil
    }

    private func pidFromSubElements(of element: AXUIElement) -> pid_t? {
        var children: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, "AXChildren" as CFString, &children) == .success,
              let childrenArray = children as? [AXUIElement]
        else { return nil }

        for child in childrenArray {
            var childPID: pid_t = 0
            if AXUIElementGetPid(child, &childPID) == .success,
               childPID != 0,
               childPID != NSRunningApplication.runningApplications(
                withBundleIdentifier: "com.apple.dock"
               ).first?.processIdentifier
            {
                return childPID
            }
        }

        return nil
    }
}
