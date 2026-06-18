import ApplicationServices
import AppKit

struct DockAppExtractor {
    static func extractApp(from dockItem: AXUIElement, runningApps: [NSRunningApplication]? = nil) -> (bundleID: String?, pid: pid_t?) {
        let apps = runningApps ?? NSWorkspace.shared.runningApplications
        
        // Strategy A: AXURL
        var axURL: CFTypeRef?
        if AXUIElementCopyAttributeValue(dockItem, "AXURL" as CFString, &axURL) == .success,
           let urlStr = axURL as? String,
           let url = URL(string: urlStr),
           let bundle = Bundle(url: url),
           let bundleID = bundle.bundleIdentifier
        {
            let pid = apps.first(where: { $0.bundleIdentifier == bundleID })?.processIdentifier
            return (bundleID, pid)
        }
        
        // Strategy B: AXTitle fallback (exact match)
        let axTitleVal = getAXTitle(from: dockItem)
        if let title = axTitleVal {
            if let pid = pidByTitle(title, in: apps) {
                return (nil, pid)
            }
        }
        
        // Strategy C: AXURL path -> parse app name from path and match
        if let urlStr = axURL as? String,
           let pid = pidByParsingAXURL(urlStr, in: apps) {
            return (nil, pid)
        }
        
        // Strategy D: Fuzzy AXTitle matching
        if let title = axTitleVal,
           let pid = pidByTitleFuzzy(title, in: apps) {
            return (nil, pid)
        }
        
        // Strategy E: Sub-element PID
        if let pid = pidFromSubElements(of: dockItem) {
            return (nil, pid)
        }
        
        return (nil, nil)
    }
    
    private static func getAXTitle(from element: AXUIElement) -> String? {
        var axTitle: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, "AXTitle" as CFString, &axTitle) == .success,
              let title = axTitle as? String
        else { return nil }
        return title
    }
    
    private static func pidByTitle(_ title: String, in apps: [NSRunningApplication]) -> pid_t? {
        return apps.first(where: { $0.localizedName == title })?.processIdentifier
    }
    
    private static func pidByParsingAXURL(_ urlStr: String, in apps: [NSRunningApplication]) -> pid_t? {
        guard let url = URL(string: urlStr) else { return nil }
        var path = url.path
        if path.hasSuffix("/") { path.removeLast() }
        
        let appName: String
        if path.hasSuffix(".app") {
            appName = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
        } else {
            appName = URL(fileURLWithPath: path).lastPathComponent
        }
        return apps.first(where: { $0.localizedName == appName })?.processIdentifier
    }
    
    private static func pidByTitleFuzzy(_ title: String, in apps: [NSRunningApplication]) -> pid_t? {
        if let app = apps.first(where: { $0.localizedName?.replacingOccurrences(of: ".app", with: "") == title }) {
            return app.processIdentifier
        }
        if let app = apps.first(where: { $0.localizedName?.caseInsensitiveCompare(title) == .orderedSame }) {
            return app.processIdentifier
        }
        if let app = apps.first(where: {
            guard let name = $0.localizedName else { return false }
            return name.contains(title) || title.contains(name)
        }) {
            return app.processIdentifier
        }
        return nil
    }
    
    private static func pidFromSubElements(of element: AXUIElement) -> pid_t? {
        var children: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, "AXChildren" as CFString, &children) == .success,
              let childrenArray = children as? [AXUIElement]
        else { return nil }
        
        let dockPID = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first?.processIdentifier
        for child in childrenArray {
            var childPID: pid_t = 0
            if AXUIElementGetPid(child, &childPID) == .success,
               childPID != 0,
               childPID != dockPID
            {
                return childPID
            }
        }
        return nil
    }
}
