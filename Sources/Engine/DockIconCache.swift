import ApplicationServices
import AppKit
import CoreGraphics
import OSLog

struct DockIconEntry {
    let frame: CGRect
    let pid: pid_t
}

final class DockIconCache {
    static let shared = DockIconCache()

    private let log = Logger(subsystem: "com.docktoggle", category: "DockIconCache")
    private let lock = NSLock()
    private var entries: [DockIconEntry] = []

    private init() {}

    var snapshot: [DockIconEntry] {
        lock.lock()
        defer { lock.unlock() }
        return entries
    }

    private var isHorizontalDock: Bool {
        guard let dockFrame = DockInspector.shared.cachedGlobalDockFrame else { return true }
        return dockFrame.width > dockFrame.height
    }

    func lookup(at point: CGPoint) -> pid_t? {
        lock.lock()
        defer { lock.unlock() }
        guard !entries.isEmpty else { return nil }
        return binaryLookup(point: point)
    }

    private func binaryLookup(point: CGPoint) -> pid_t? {
        let horizontal = isHorizontalDock

        var lo = 0
        var hi = entries.count

        while lo < hi {
            let mid = (lo + hi) / 2
            let coord = horizontal ? entries[mid].frame.minX : entries[mid].frame.minY
            if coord <= (horizontal ? point.x : point.y) {
                lo = mid + 1
            } else {
                hi = mid
            }
        }

        let start = max(0, lo - 1)
        let end = min(entries.count - 1, lo)
        for i in start...end {
            if entries[i].frame.contains(point) {
                return entries[i].pid
            }
        }
        return nil
    }

    func refresh() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.performRefresh()
        }
    }

    private func performRefresh() {
        guard let dock = NSRunningApplication.runningApplications(
            withBundleIdentifier: "com.apple.dock"
        ).first else {
            log.error("Dock process not found")
            DebugLog.shared.write("[CACHE] Dock process not found")
            return
        }

        let dockElement = AXUIElementCreateApplication(dock.processIdentifier)

        guard let dockItemList = findDockItemList(from: dockElement) else {
            log.error("Could not find Dock item list")
            DebugLog.shared.write("[CACHE] No AXList found")
            return
        }

        let dockItems = collectDockItems(from: dockItemList)
        DebugLog.shared.write("[CACHE] found \(dockItems.count) DockItem elements")

        var newEntries: [DockIconEntry] = []

        for item in dockItems {
            guard let frame = axFrame(of: item) ?? axPositionAndSize(of: item) else {
                DebugLog.shared.write("[CACHE] no frame for a DockItem")
                continue
            }

            guard let pid = extractPID(from: item) else {
                DebugLog.shared.write("[CACHE] no pid for DockItem at frame=\(frame)")
                continue
            }

            DebugLog.shared.write("[CACHE] DockItem pid=\(pid) frame=\(frame.origin.x),\(frame.origin.y) \(frame.width)x\(frame.height)")
            newEntries.append(DockIconEntry(frame: frame, pid: pid))
        }

        if !newEntries.isEmpty {
            if isHorizontalDock {
                newEntries.sort { $0.frame.minX < $1.frame.minX }
            } else {
                newEntries.sort { $0.frame.minY < $1.frame.minY }
            }
        }

        lock.lock()
        entries = newEntries
        lock.unlock()

        log.info("DockIconCache refreshed: \(newEntries.count) icons")
        DebugLog.shared.write("[CACHE] refreshed \(newEntries.count) icons")
    }

    private func findDockItemList(from dockElement: AXUIElement) -> AXUIElement? {
        var children: CFTypeRef?
        guard AXUIElementCopyAttributeValue(dockElement,
                "AXChildren" as CFString, &children) == .success,
              let childrenArray = children as? [AXUIElement]
        else { return nil }

        for child in childrenArray {
            var role: CFTypeRef?
            AXUIElementCopyAttributeValue(child, "AXRole" as CFString, &role)
            if let roleStr = role as? String, roleStr == "AXList" {
                return child
            }
        }
        return nil
    }

    private func collectDockItems(from element: AXUIElement, depth: Int = 0) -> [AXUIElement] {
        guard depth < 8 else { return [] }

        var role: CFTypeRef?
        AXUIElementCopyAttributeValue(element, "AXRole" as CFString, &role)
        let roleStr = (role as? String) ?? ""

        if roleStr.lowercased().contains("dockitem") {
            return [element]
        }

        var children: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element,
                "AXChildren" as CFString, &children) == .success,
              let childrenArray = children as? [AXUIElement]
        else { return [] }

        var results: [AXUIElement] = []
        for child in childrenArray {
            results.append(contentsOf: collectDockItems(from: child, depth: depth + 1))
        }
        return results
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

    private func extractPID(from dockItem: AXUIElement) -> pid_t? {
        // Strategy A: AXURL
        var axURL: CFTypeRef?
        if AXUIElementCopyAttributeValue(dockItem,
                "AXURL" as CFString, &axURL) == .success,
           let urlStr = axURL as? String,
           let url = URL(string: urlStr),
           let bundle = Bundle(url: url),
           let bundleID = bundle.bundleIdentifier
        {
            return NSWorkspace.shared.runningApplications
                .first(where: { $0.bundleIdentifier == bundleID })?
                .processIdentifier
        }

        // Strategy B: AXTitle fallback
        var axTitle: CFTypeRef?
        guard AXUIElementCopyAttributeValue(dockItem,
                "AXTitle" as CFString, &axTitle) == .success,
              let title = axTitle as? String
        else { return nil }

        return NSWorkspace.shared.runningApplications
            .first(where: { $0.localizedName == title })?
            .processIdentifier
    }
}
