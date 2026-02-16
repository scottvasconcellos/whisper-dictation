import AppKit

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

        do {
            try FileManager.default.removeItem(atPath: triggerPath)
        } catch {
            log("Failed to remove trigger: \(error)")
            return
        }

        Thread.sleep(forTimeInterval: 0.3)

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        task.arguments = ["-e", "tell application \"System Events\" to keystroke \"v\" using command down"]
        do {
            try task.run()
            task.waitUntilExit()
            if task.terminationStatus != 0 {
                log("osascript exit code: \(task.terminationStatus)")
            }
        } catch {
            log("osascript failed: \(error)")
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
