import AppKit
import ApplicationServices

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    var timer: Timer?
    let triggerPath = NSString(string: "~/.whisper-paste-trigger/request").expandingTildeInPath
    let pasteWatcherLog = NSString(string: "~/whisper-sessions/paste-watcher.log").expandingTildeInPath

    func applicationDidFinishLaunching(_ notification: Notification) {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.checkTrigger()
        }
        RunLoop.current.add(timer!, forMode: .common)
    }

    func checkTrigger() {
        guard FileManager.default.fileExists(atPath: triggerPath) else { return }

        guard let text = try? String(contentsOfFile: triggerPath, encoding: .utf8), !text.isEmpty else {
            try? FileManager.default.removeItem(atPath: triggerPath)
            return
        }

        do {
            try FileManager.default.removeItem(atPath: triggerPath)
        } catch {
            log("Failed to remove trigger: \(error)")
            return
        }

        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            Thread.sleep(forTimeInterval: 0.3)
            DispatchQueue.main.async {
                self?.insertText(text)
            }
        }
    }

    /// Inserts text at the current cursor position using the Accessibility API.
    /// Sets kAXSelectedTextAttribute on the focused element, which replaces any
    /// selection or inserts at cursor — no clipboard involved.
    private func insertText(_ text: String) {
        guard AXIsProcessTrusted() else {
            log("Accessibility not granted — cannot type text")
            return
        }
        let systemWide = AXUIElementCreateSystemWide()
        var focusedRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focusedRef) == .success,
              let focused = focusedRef else {
            log("No focused element found")
            return
        }
        let result = AXUIElementSetAttributeValue(focused as! AXUIElement, kAXSelectedTextAttribute as CFString, text as CFTypeRef)
        if result != .success {
            log("AXUIElement insert failed (code \(result.rawValue)) — no fallback, clipboard untouched")
        }
    }

    func log(_ message: String) {
        let line = "\(ISO8601DateFormatter().string(from: Date())) \(message)\n"
        let dir = (pasteWatcherLog as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        guard let data = line.data(using: .utf8) else { return }
        if FileManager.default.fileExists(atPath: pasteWatcherLog) {
            if let handle = try? FileHandle(forUpdating: URL(fileURLWithPath: pasteWatcherLog)) {
                handle.seekToEndOfFile()
                handle.write(data)
                try? handle.close()
            }
        } else {
            try? data.write(to: URL(fileURLWithPath: pasteWatcherLog))
        }
    }
}
