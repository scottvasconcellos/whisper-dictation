import AppKit
import Foundation

// #region agent log
func debugLog(_ message: String, _ data: [String: Any] = [:]) {
    let home = FileManager.default.homeDirectoryForCurrentUser.path
    let logPath = "\(home)/whisper-sessions/debug.log"
    let dir = (logPath as NSString).deletingLastPathComponent
    try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
    let payload: [String: Any] = [
        "runId": "main-\(Int(Date().timeIntervalSince1970))-\(ProcessInfo.processInfo.processIdentifier)",
        "hypothesisId": "STARTUP",
        "location": "main.swift",
        "message": message,
        "data": data,
        "timestamp": Int(Date().timeIntervalSince1970 * 1000)
    ]
    guard let body = try? JSONSerialization.data(withJSONObject: payload) else { return }
    var line = body
    line.append(0x0A)
    if FileManager.default.fileExists(atPath: logPath),
       let handle = try? FileHandle(forUpdating: URL(fileURLWithPath: logPath)) {
        handle.seekToEndOfFile()
        handle.write(line)
        try? handle.close()
    } else {
        try? line.write(to: URL(fileURLWithPath: logPath))
    }
}
// #endregion

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
