import Foundation

/// Canonical event schema for WhisperDictation debugging and acceptance testing.
/// All events are written as JSONL to ~/whisper-sessions/events.log
enum EventLogger {
    private static let logPath: String = {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/whisper-sessions/events.log"
    }()
    
    private static func writeEvent(_ event: [String: Any]) {
        let payload: [String: Any] = [
            "timestamp": Int(Date().timeIntervalSince1970 * 1000),
            "pid": ProcessInfo.processInfo.processIdentifier
        ].merging(event) { _, new in new }
        
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let line = String(data: data, encoding: .utf8) else { return }
        
        let dir = (logPath as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        
        let logLine = line + "\n"
        if let logData = logLine.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logPath),
               let handle = try? FileHandle(forUpdating: URL(fileURLWithPath: logPath)) {
                handle.seekToEndOfFile()
                handle.write(logData)
                try? handle.close()
            } else {
                try? logData.write(to: URL(fileURLWithPath: logPath))
            }
        }
    }
    
    // MARK: - Event Types
    
    static func sessionStart(sessionId: String) {
        writeEvent([
            "event": "session_start",
            "sessionId": sessionId
        ])
    }
    
    static func recordingStarted(sessionId: String) {
        writeEvent([
            "event": "recording_started",
            "sessionId": sessionId
        ])
    }
    
    static func stopRequested(sessionId: String, reason: String) {
        writeEvent([
            "event": "stop_requested",
            "sessionId": sessionId,
            "stopReason": reason  // "manual" or "silence"
        ])
    }
    
    static func stopIgnored(sessionId: String?, reason: String) {
        writeEvent([
            "event": "stop_ignored",
            "sessionId": sessionId ?? "",
            "reason": reason
        ])
    }
    
    static func transcriptionStarted(sessionId: String) {
        writeEvent([
            "event": "transcription_started",
            "sessionId": sessionId
        ])
    }
    
    static func transcriptionComplete(sessionId: String, textLength: Int) {
        writeEvent([
            "event": "transcription_complete",
            "sessionId": sessionId,
            "textLength": textLength
        ])
    }
    
    static func startIgnored(reason: String) {
        writeEvent([
            "event": "start_ignored",
            "reason": reason
        ])
    }
    
    static func error(sessionId: String?, message: String, context: [String: Any] = [:]) {
        var event: [String: Any] = [
            "event": "error",
            "message": message
        ]
        if let sid = sessionId {
            event["sessionId"] = sid
        }
        event.merge(context) { _, new in new }
        writeEvent(event)
    }
}
