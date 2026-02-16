import Foundation

/// Loads key=value config from ~/.config/whisper-dictation/config (same keys as common.sh).
struct Config {
    var sessionsDir: String
    var triggerDir: String
    var recordStartTrigger: String
    var recordStopTrigger: String
    var whisperBin: String
    var whisperModel: String
    var sessionRetentionDays: Int
    var silenceDurationSec: Int

    static func load() -> Config {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let xdg = "\(home)/.config/whisper-dictation/config"
        let legacy = "\(home)/.whisper-dictation/config"
        let path: String
        if FileManager.default.fileExists(atPath: xdg) { path = xdg }
        else if FileManager.default.fileExists(atPath: legacy) { path = legacy }
        else { path = xdg }

        var sessionsDir = "\(home)/whisper-sessions"
        var triggerDir = "\(home)/.whisper-trigger"
        var recordStartTrigger = ""
        var recordStopTrigger = ""
        var whisperModel = "\(home)/whisper-models/ggml-small.bin"
        var whisperBin = ""
        var sessionRetentionDays = 7
        var silenceDurationSec = 8

        if let content = try? String(contentsOfFile: path, encoding: .utf8) {
            for line in content.components(separatedBy: .newlines) {
                let trimmed = line.split(separator: "#").first.map(String.init)?.trimmingCharacters(in: .whitespaces) ?? ""
                guard let eq = trimmed.firstIndex(of: "=") else { continue }
                let key = String(trimmed[..<eq]).trimmingCharacters(in: .whitespaces)
                var val = String(trimmed[trimmed.index(after: eq)...]).trimmingCharacters(in: .whitespaces)
                val = (val as NSString).expandingTildeInPath

                switch key {
                case "SESSIONS_DIR": sessionsDir = val
                case "TRIGGER_DIR", "RECORD_START_TRIGGER", "RECORD_STOP_TRIGGER": break // ignored; we force ~/.whisper-trigger
                case "WHISPER_MODEL": whisperModel = val
                case "WHISPER_BIN": whisperBin = val
                case "SESSION_RETENTION_DAYS": sessionRetentionDays = Int(val) ?? 7
                case "SILENCE_DURATION_SEC": silenceDurationSec = Int(val) ?? 8
                default: break
                }
            }
        }

        // Force canonical trigger path: always ~/.whisper-trigger (config ignored) so app and scripts never disagree
        triggerDir = "\(home)/.whisper-trigger"
        recordStartTrigger = "\(home)/.whisper-trigger/record-start"
        recordStopTrigger = "\(home)/.whisper-trigger/record-stop"
        if whisperBin.isEmpty {
            for candidate in ["/opt/homebrew/bin/whisper-cli", "/usr/local/bin/whisper-cli"] {
                if FileManager.default.isExecutableFile(atPath: candidate) {
                    whisperBin = candidate
                    break
                }
            }
        }

        return Config(
            sessionsDir: sessionsDir,
            triggerDir: triggerDir,
            recordStartTrigger: recordStartTrigger,
            recordStopTrigger: recordStopTrigger,
            whisperBin: whisperBin,
            whisperModel: whisperModel,
            sessionRetentionDays: sessionRetentionDays,
            silenceDurationSec: silenceDurationSec
        )
    }
}
