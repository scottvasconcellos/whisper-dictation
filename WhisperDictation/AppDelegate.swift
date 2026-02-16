import AppKit
import AVFoundation
import Foundation

/// Runtime state machine for WhisperDictation
enum DictationState {
    case idle
    case recording
    case stopping
    case transcribing
    case pasting
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var config: Config!
    private var pollTimer: Timer?
    private var recorder: Recorder?
    private var state: DictationState = .idle
    private var currentSessionId: String?
    private var stopRequestedReason: String? // "manual" or "silence" - manual always wins
    private var stopRequestedAt: Date?
    private var recordingStartedAt: Date?

    func applicationDidFinishLaunching(_ notification: Notification) {
        config = Config.load()
        EventLogger.error(sessionId: nil, message: "app_launched", context: ["pid": ProcessInfo.processInfo.processIdentifier])
        
        // Request mic at launch when not yet determined so the system prompt appears
        if AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined {
            AVCaptureDevice.requestAccess(for: .audio) { _ in }
        }
        
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
            self?.pollTriggers()
        }
        RunLoop.current.add(pollTimer!, forMode: .common)
    }

    private func pollTriggers() {
        let startExists = FileManager.default.fileExists(atPath: config.recordStartTrigger)
        let stopExists = FileManager.default.fileExists(atPath: config.recordStopTrigger)
        
        if startExists {
            try? FileManager.default.removeItem(atPath: config.recordStartTrigger)
            handleStart()
        }
        if stopExists {
            try? FileManager.default.removeItem(atPath: config.recordStopTrigger)
            handleStop(manual: true)
        }
    }

    private func handleStart() {
        // Ignore start requests if not idle (double-tap during recording should be ignored)
        guard state == .idle else {
            EventLogger.startIgnored(reason: "state_not_idle_\(state)")
            return
        }
        
        // Check mic permission
        let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        
        if micStatus == .authorized {
            startRecording()
        } else if micStatus == .notDetermined {
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self = self, granted, self.state == .idle else { return }
                    self.startRecording()
                }
            }
        } else {
            EventLogger.error(sessionId: nil, message: "microphone_not_authorized", context: ["status": micStatus.rawValue])
        }
    }

    private func startRecording() {
        guard state == .idle else { return }
        
        try? FileManager.default.createDirectory(atPath: config.sessionsDir, withIntermediateDirectories: true)
        let sessionId = sessionIdFromDate()
        let sessionDir = "\(config.sessionsDir)/\(sessionId)"
        try? FileManager.default.createDirectory(atPath: sessionDir, withIntermediateDirectories: true)
        try? sessionId.write(toFile: "\(config.sessionsDir)/current_session", atomically: true, encoding: .utf8)
        
        currentSessionId = sessionId
        state = .recording
        recordingStartedAt = Date()
        stopRequestedReason = nil
        stopRequestedAt = nil
        
        EventLogger.sessionStart(sessionId: sessionId)
        
        let wavPath = "\(sessionDir)/recording.wav"
        recorder = Recorder(silenceDurationSec: config.silenceDurationSec)
        recorder?.onSilenceDetected = { [weak self] in
            DispatchQueue.main.async { self?.handleStop(manual: false) }
        }
        
        do {
            try recorder?.startRecording(to: wavPath)
            SoundHelper.playPing()
            EventLogger.recordingStarted(sessionId: sessionId)
        } catch {
            SoundHelper.playError()
            EventLogger.error(sessionId: sessionId, message: "recording_start_failed", context: ["error": String(describing: error)])
            currentSessionId = nil
            recorder = nil
            state = .idle
        }
    }

    private func handleStop(manual: Bool) {
        // Idempotent stop: if already stopping/transcribing/pasting, ignore unless manual takes precedence
        if state == .stopping || state == .transcribing || state == .pasting {
            if manual && stopRequestedReason != "manual" {
                // Manual stop always wins - but we're already in pipeline, so log and continue
                stopRequestedReason = "manual"
                EventLogger.stopRequested(sessionId: currentSessionId ?? "", reason: "manual")
            } else {
                EventLogger.stopIgnored(sessionId: currentSessionId, reason: "already_\(state)")
            }
            return
        }
        
        guard state == .recording, let rec = recorder, let sessionId = currentSessionId else {
            EventLogger.stopIgnored(sessionId: currentSessionId, reason: "not_recording")
            return
        }
        
        // Manual stop always takes precedence over silence
        let reason = manual ? "manual" : (stopRequestedReason ?? "silence")
        if manual {
            stopRequestedReason = "manual"
            stopRequestedAt = Date()
        } else if stopRequestedReason == nil {
            stopRequestedReason = "silence"
            stopRequestedAt = Date()
        }
        
        EventLogger.stopRequested(sessionId: sessionId, reason: reason)
        
        state = .stopping
        recorder = nil
        
        let sessionDir = "\(config.sessionsDir)/\(sessionId)"
        let wavPath = "\(sessionDir)/recording.wav"
        
        do {
            _ = try rec.stopRecording()
        } catch {
            EventLogger.error(sessionId: sessionId, message: "recording_stop_failed", context: ["error": String(describing: error)])
        }
        
        // Capture frontmost app at stop time — we paste into this app when we're done.
        // If you switch to another app during the few seconds of transcription, we still paste
        // into the app you were in when you tapped stop (and we'll bring it back to front first).
        let targetApp = NSWorkspace.shared.frontmostApplication
        runWhisperThenPaste(wavPath: wavPath, sessionDir: sessionDir, sessionId: sessionId, targetApp: targetApp)
    }

    private func runWhisperThenPaste(wavPath: String, sessionDir: String, sessionId: String, targetApp: NSRunningApplication?) {
        guard state == .stopping else { return }
        
        state = .transcribing
        EventLogger.transcriptionStarted(sessionId: sessionId)
        
        guard FileManager.default.fileExists(atPath: wavPath) else {
            EventLogger.error(sessionId: sessionId, message: "wav_file_missing", context: ["path": wavPath])
            SoundHelper.playError()
            resetToIdle(sessionDir: sessionDir)
            return
        }
        guard !config.whisperBin.isEmpty, FileManager.default.isExecutableFile(atPath: config.whisperBin) else {
            EventLogger.error(sessionId: sessionId, message: "whisper_bin_invalid", context: ["bin": config.whisperBin])
            SoundHelper.playError()
            resetToIdle(sessionDir: sessionDir)
            return
        }
        guard FileManager.default.fileExists(atPath: config.whisperModel) else {
            EventLogger.error(sessionId: sessionId, message: "whisper_model_missing", context: ["model": config.whisperModel])
            SoundHelper.playError()
            resetToIdle(sessionDir: sessionDir)
            return
        }

        // Run Whisper and wait until it exits — we only proceed (and paste) when it's definitively done.
        let task = Process()
        task.executableURL = URL(fileURLWithPath: config.whisperBin)
        task.arguments = ["-m", config.whisperModel, "-f", wavPath, "-otxt"]
        task.currentDirectoryURL = URL(fileURLWithPath: sessionDir)
        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            EventLogger.error(sessionId: sessionId, message: "whisper_process_failed", context: ["error": String(describing: error)])
            SoundHelper.playError()
            resetToIdle(sessionDir: sessionDir)
            return
        }

        let txtPath = "\(wavPath).txt"
        guard let text = try? String(contentsOfFile: txtPath, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else {
            EventLogger.error(sessionId: sessionId, message: "transcript_empty_or_missing", context: ["txtPath": txtPath])
            SoundHelper.playError()
            resetToIdle(sessionDir: sessionDir)
            return
        }
        
        EventLogger.transcriptionComplete(sessionId: sessionId, textLength: text.count)

        // Always write to clipboard first
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        
        state = .pasting
        
        // Calculate latency from stop request to paste attempt
        let latencyMs: Int?
        if let stopTime = stopRequestedAt {
            latencyMs = Int((Date().timeIntervalSince(stopTime) * 1000).rounded())
        } else {
            latencyMs = nil
        }
        
        // Bring target app to front so Hammerspoon’s Cmd+V goes there
        if let app = targetApp, app != NSRunningApplication.current {
            app.activate(options: [])
            Thread.sleep(forTimeInterval: 0.15)
        }
        
        // Single paste path: write trigger file; Hammerspoon watches and sends Cmd+V
        let pasteTriggerPath = "\(config.triggerDir)/paste-request"
        try? FileManager.default.createDirectory(atPath: config.triggerDir, withIntermediateDirectories: true)
        try? "".write(toFile: pasteTriggerPath, atomically: true, encoding: .utf8)
        var triggerContext: [String: Any] = ["path": pasteTriggerPath]
        if let lat = latencyMs { triggerContext["latencyMs"] = lat }
        EventLogger.error(sessionId: sessionId, message: "paste_trigger_written", context: triggerContext)
        SoundHelper.playFrog()
        
        resetToIdle(sessionDir: sessionDir)
    }
    
    private func resetToIdle(sessionDir: String) {
        state = .idle
        currentSessionId = nil
        recorder = nil
        stopRequestedReason = nil
        stopRequestedAt = nil
        recordingStartedAt = nil
        pruneAndClear(sessionDir: sessionDir)
    }

    private func pruneAndClear(sessionDir: String) {
        try? FileManager.default.removeItem(atPath: "\(config.sessionsDir)/current_session")
        let days = config.sessionRetentionDays
        guard let enumerator = FileManager.default.enumerator(atPath: config.sessionsDir) else { return }
        let cutoff = Date().addingTimeInterval(-Double(days * 86400))
        while let name = enumerator.nextObject() as? String {
            let full = "\(config.sessionsDir)/\(name)"
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: full, isDirectory: &isDir), isDir.boolValue else { continue }
            guard name.hasPrefix("20"), name.count >= 15 else { continue }
            if let attrs = try? FileManager.default.attributesOfItem(atPath: full),
               let mod = attrs[.modificationDate] as? Date, mod < cutoff {
                try? FileManager.default.removeItem(atPath: full)
            }
        }
    }

    private func sessionIdFromDate() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd-HHmmss"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: Date())
    }
}
