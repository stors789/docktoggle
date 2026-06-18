import Foundation
import os

final class DebugLog {
    static let shared = DebugLog()
    let url: URL
    private let queue = DispatchQueue(label: "com.docktoggle.debuglog")
    private var fileHandle: FileHandle?
    
    // Buffering & Logger variables
    private var buffer: [String] = []
    private let maxBufferSize = 50
    private var timer: DispatchSourceTimer?
    private let logger = Logger(subsystem: "com.docktoggle", category: "DebugLog")

    private init() {
        let logsDirectory = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/DockToggle", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: logsDirectory,
            withIntermediateDirectories: true
        )
        url = logsDirectory.appendingPathComponent("docktoggle.log")
        rotateIfNeeded()
        fileHandle = try? FileHandle(forWritingTo: url)
        if fileHandle == nil {
            FileManager.default.createFile(atPath: url.path, contents: nil)
            fileHandle = try? FileHandle(forWritingTo: url)
        }
        fileHandle?.seekToEndOfFile()
        
        setupTimer()
        write("=== DockToggle \(Date()) ===")
    }

    private func setupTimer() {
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now() + 3.0, repeating: 3.0)
        t.setEventHandler { [weak self] in
            self?.flushPending()
        }
        t.resume()
        timer = t
    }

    func write(_ msg: String) {
        // Parallel logging to os_log
        logger.debug("\(msg, privacy: .public)")

        let line = "[\(Date())] \(msg)\n"
        queue.async { [weak self] in
            guard let self else { return }
            self.buffer.append(line)
            if self.buffer.count >= self.maxBufferSize {
                self.flushPending()
            }
        }
    }

    private func flushPending() {
        guard !buffer.isEmpty, let fh = fileHandle else { return }
        let joined = buffer.joined()
        buffer.removeAll()
        if let data = joined.data(using: .utf8) {
            do {
                try fh.write(contentsOf: data)
            } catch {
                // Ignore write failures silently
            }
        }
    }

    func flush() {
        queue.sync {
            self.flushPending()
        }
    }

    func recentLines(limit: Int = 80) -> String {
        queue.sync {
            self.flushPending()
            guard let content = try? String(contentsOf: url, encoding: .utf8) else {
                return "Log file not found at \(url.path)"
            }
            return content.components(separatedBy: "\n")
                .suffix(limit)
                .joined(separator: "\n")
        }
    }

    func clear() {
        queue.sync {
            buffer.removeAll()
            try? fileHandle?.truncate(atOffset: 0)
            try? fileHandle?.synchronize()
        }
        write("=== DockToggle log cleared \(Date()) ===")
    }

    private func rotateIfNeeded() {
        let maxBytes: UInt64 = 1_000_000
        guard let size = try? FileManager.default
            .attributesOfItem(atPath: url.path)[.size] as? UInt64,
              size > maxBytes
        else { return }

        let archive = url.deletingPathExtension().appendingPathExtension("old.log")
        try? FileManager.default.removeItem(at: archive)
        try? FileManager.default.moveItem(at: url, to: archive)
    }
}

