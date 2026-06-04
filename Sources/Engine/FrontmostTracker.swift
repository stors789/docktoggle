import AppKit
import os

final class FrontmostTracker {
    static let shared = FrontmostTracker()

    private let _lock: OSAllocatedUnfairLock<Int32> = .init(initialState: 0)
    private var observer: NSObjectProtocol?

    var currentPID: pid_t {
        _lock.withLock { $0 }
    }

    private init() {
        let initial = NSWorkspace.shared.frontmostApplication?.processIdentifier ?? 0
        _lock.withLock { $0 = initial }

        observer = NSWorkspace.shared.notificationCenter
            .addObserver(
                forName: NSWorkspace.didActivateApplicationNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                guard let self,
                      let app = notification.userInfo?[
                        NSWorkspace.applicationUserInfoKey
                      ] as? NSRunningApplication
                else { return }
                self._lock.withLock { $0 = app.processIdentifier }
            }
    }
}
