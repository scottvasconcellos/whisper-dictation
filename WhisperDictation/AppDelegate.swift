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
    private var statusItem: NSStatusItem?
    private var animationTimer: Timer?
    private var animationFrame: Int = 0
    private var recentTranscripts: [String] = []
    private var state: DictationState = .idle {
        didSet { updateStatusBar() }
    }
    private var currentSessionId: String?
    private var stopRequestedReason: String? // "manual" or "silence" - manual always wins
    private var stopRequestedAt: Date?
    private var recordingStartedAt: Date?

    func applicationDidFinishLaunching(_ notification: Notification) {
        config = Config.load()
        setupStatusBar()
        EventLogger.error(sessionId: nil, message: "app_launched", context: ["pid": ProcessInfo.processInfo.processIdentifier])
        try? FileManager.default.createDirectory(atPath: config.triggerDir, withIntermediateDirectories: true)
        let pasteTriggerDirAlt = "\(FileManager.default.homeDirectoryForCurrentUser.path)/.whisper-paste-trigger"
        try? FileManager.default.createDirectory(atPath: pasteTriggerDirAlt, withIntermediateDirectories: true)
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

    private static let whisperTimeoutSeconds: TimeInterval = 120

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

        let whisperBin = config.whisperBin
        let whisperModel = config.whisperModel
        let triggerDir = config.triggerDir
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let pasteTriggerDirAlt = "\(home)/.whisper-paste-trigger"

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            var transcript: String?
            var failedMessage: String?

            do {
                let task = Process()
                task.executableURL = URL(fileURLWithPath: whisperBin)
                task.arguments = ["-m", whisperModel, "-f", wavPath, "-otxt",
                                  "--prompt", "Claude Code, Anthropic. Continuous prose, no paragraph breaks."]
                task.currentDirectoryURL = URL(fileURLWithPath: sessionDir)
                try task.run()
                var timedOut = false
                let timeoutItem = DispatchWorkItem {
                    timedOut = true
                    task.terminate()
                }
                DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + Self.whisperTimeoutSeconds, execute: timeoutItem)
                task.waitUntilExit()
                timeoutItem.cancel()
                if timedOut {
                    failedMessage = "whisper_timeout"
                } else if task.terminationStatus != 0 {
                    failedMessage = "whisper_exit_\(task.terminationStatus)"
                } else {
                    let txtPath = "\(wavPath).txt"
                    let raw = try? String(contentsOfFile: txtPath, encoding: .utf8)
                        .components(separatedBy: .newlines)
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                        .filter { !$0.isEmpty }
                        .joined(separator: " ")
                    if let t = raw, !t.isEmpty {
                        transcript = t
                    } else {
                        failedMessage = "transcript_empty_or_missing"
                    }
                }
            } catch {
                failedMessage = "whisper_process_failed"
            }

            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                if let msg = failedMessage {
                    EventLogger.error(sessionId: sessionId, message: msg, context: [:])
                    SoundHelper.playError()
                    self.resetToIdle(sessionDir: sessionDir)
                    return
                }
                guard let text = transcript else {
                    self.resetToIdle(sessionDir: sessionDir)
                    return
                }

                EventLogger.transcriptionComplete(sessionId: sessionId, textLength: text.count)
                self.addToHistory(text)
                state = .pasting

                let latencyMs: Int?
                if let stopTime = stopRequestedAt {
                    latencyMs = Int((Date().timeIntervalSince(stopTime) * 1000).rounded())
                } else {
                    latencyMs = nil
                }

                let writeTriggers = { [weak self] in
                    guard let self = self else { return }
                    // Write text into trigger files — Hammerspoon/WhisperPaste read it and type
                    // directly into the focused field. Clipboard is never touched.
                    try? FileManager.default.createDirectory(atPath: triggerDir, withIntermediateDirectories: true)
                    let pasteTriggerPath = "\(triggerDir)/paste-request"
                    try? text.write(toFile: pasteTriggerPath, atomically: true, encoding: .utf8)
                    try? FileManager.default.createDirectory(atPath: pasteTriggerDirAlt, withIntermediateDirectories: true)
                    let pasteTriggerPathAlt = "\(pasteTriggerDirAlt)/request"
                    try? text.write(toFile: pasteTriggerPathAlt, atomically: true, encoding: .utf8)
                    EventLogger.pasteTriggered(sessionId: sessionId, latencyMs: latencyMs)
                    SoundHelper.playFrog()
                    self.resetToIdle(sessionDir: sessionDir)
                }

                if let app = targetApp, app != NSRunningApplication.current {
                    app.activate(options: [])
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: writeTriggers)
                } else {
                    writeTriggers()
                }
            }
        }
    }
    
    // MARK: - Status Bar

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = nil
            button.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .medium)
        }
        rebuildMenu()
        updateStatusBar()
    }

    private func addToHistory(_ text: String) {
        recentTranscripts.insert(text, at: 0)
        if recentTranscripts.count > 5 { recentTranscripts.removeLast() }
        rebuildMenu()
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        // History section
        let header = NSMenuItem(title: "Recent Dictations", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())

        if recentTranscripts.isEmpty {
            let empty = NSMenuItem(title: "No recent dictations", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        } else {
            for (i, transcript) in recentTranscripts.enumerated() {
                let preview = transcript.count > 55
                    ? String(transcript.prefix(52)) + "…"
                    : transcript
                let item = NSMenuItem(title: "\(i + 1).  \(preview)", action: #selector(copyHistoryItem(_:)), keyEquivalent: "")
                item.target = self
                item.toolTip = transcript   // hover shows full text
                item.representedObject = transcript
                menu.addItem(item)
            }
        }

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit WhisperDictation", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem?.menu = menu
    }

    @objc private func copyHistoryItem(_ sender: NSMenuItem) {
        guard let text = sender.representedObject as? String else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func updateStatusBar() {
        animationTimer?.invalidate()
        animationTimer = nil
        animationFrame = 0

        switch state {
        case .idle:
            setLabel("Whisper", color: .secondaryLabelColor)

        case .recording:
            // Pulse: filled dot alternates with empty dot
            setLabel("Whisper  ● rec", color: .systemRed)
            animationTimer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                self.animationFrame += 1
                let dot = self.animationFrame % 2 == 0 ? "●" : "○"
                self.setLabel("Whisper  \(dot) rec", color: .systemRed)
            }

        case .stopping, .transcribing:
            // Cycling dots: Processing· → Processing·· → Processing···
            setLabel("Whisper  Processing·", color: .systemOrange)
            animationTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                self.animationFrame += 1
                let dots = String(repeating: "·", count: (self.animationFrame % 3) + 1)
                self.setLabel("Whisper  Processing\(dots)", color: .systemOrange)
            }

        case .pasting:
            setLabel("Whisper  Done ✓", color: .systemGreen)
        }
    }

    private func setLabel(_ text: String, color: NSColor) {
        guard let button = statusItem?.button else { return }
        let attrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: color,
            .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .medium)
        ]
        button.attributedTitle = NSAttributedString(string: text, attributes: attrs)
    }

    // MARK: - Idle

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
        let keepCount = config.sessionRetentionCount
        guard let contents = try? FileManager.default.contentsOfDirectory(atPath: config.sessionsDir) else { return }
        var sessionDirs: [(name: String, modDate: Date)] = []
        for name in contents {
            let full = "\(config.sessionsDir)/\(name)"
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: full, isDirectory: &isDir), isDir.boolValue else { continue }
            guard name.hasPrefix("20"), name.count >= 15 else { continue }
            if let attrs = try? FileManager.default.attributesOfItem(atPath: full),
               let mod = attrs[.modificationDate] as? Date {
                sessionDirs.append((name: name, modDate: mod))
            }
        }
        sessionDirs.sort { $0.modDate > $1.modDate }
        for index in keepCount..<sessionDirs.count {
            let full = "\(config.sessionsDir)/\(sessionDirs[index].name)"
            try? FileManager.default.removeItem(atPath: full)
        }
    }

    private func sessionIdFromDate() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd-HHmmss"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: Date())
    }
}
