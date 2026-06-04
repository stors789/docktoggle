import Foundation

final class DebugLog {
    static let shared = DebugLog()
    private let url = URL(fileURLWithPath: "/tmp/docktoggle.log")
    private let queue = DispatchQueue(label: "com.docktoggle.debuglog")
    private var fileHandle: FileHandle?

    private init() {
        try? "".write(to: url, atomically: true, encoding: .utf8)
        fileHandle = try? FileHandle(forWritingTo: url)
        fileHandle?.seekToEndOfFile()
        write("=== DockToggle \(Date()) ===")
    }

    func write(_ msg: String) {
        let line = "[\(Date())] \(msg)\n"
        queue.async { [weak self] in
            guard let self, let fh = self.fileHandle,
                  let data = line.data(using: .utf8) else { return }
            fh.write(data)
        }
    }
}
