# WhisperDictation — Product Requirements Document

## Overview

WhisperDictation is a local, privacy-first macOS dictation utility. It lets you speak and have your words automatically typed into any text field — no cloud, no subscription, no clipboard hijacking.

---

## MVP (v1.0) — Shipped

### Core User Flow

1. **Double-tap Control** → recording starts (Karabiner-Elements detects the double-tap and writes a trigger file)
2. **Single-tap Control** → recording stops manually
3. **8-second silence timeout** → recording stops automatically if no key press and silence is detected
4. **Transcription** → audio is processed locally via `whisper-cli` (on-device ML, no network)
5. **Auto-paste** → transcribed text is typed directly into the previously focused text field

### What "Auto-paste" Means

- The app captures which app had focus when recording started
- After transcription, that app is re-activated
- Text is injected via Hammerspoon (`hs.eventtap.keyStrokes`) — **no clipboard involved**
- Your existing clipboard is never touched or overwritten

### Components

| Component | Role |
|---|---|
| Karabiner-Elements | Detects double-tap Control, writes `~/.whisper-trigger/record-start` |
| `WhisperDictation.app` | State machine: polls trigger files, drives AVAudioEngine recording, runs whisper-cli, dispatches paste trigger |
| `whisper-cli` | On-device transcription (whisper.cpp), runs locally, no network |
| Hammerspoon | Watches `~/.whisper-trigger/paste-request`, types text via `hs.eventtap.keyStrokes()` |
| `WhisperPaste.app` | Fallback paste agent (osascript) if Hammerspoon is not running |

### Trigger File Protocol

All inter-process communication uses files in `~/.whisper-trigger/`:

| File | Written by | Meaning |
|---|---|---|
| `record-start` | Karabiner | Begin recording |
| `record-stop` | Karabiner | Stop recording manually |
| `paste-request` | WhisperDictation | Paste the transcribed text (text content = the transcript) |

### Recording Behaviour

- Audio captured at 16kHz mono via AVAudioEngine
- Silence detection: stops automatically after **8 seconds** of silence below threshold
- Hard cap: recording never runs forever — silence timeout is the safety net
- WAV file saved to `~/whisper-sessions/<session-id>/recording.wav`

### Session Management

- Each dictation cycle creates a timestamped session directory under `~/whisper-sessions/`
- After each cycle, old sessions are pruned — only the **5 most recent** are kept
- Deleted automatically: WAV audio files and whisper transcript output
- Events logged to `~/whisper-sessions/events.log` (JSONL) for debugging

### Privacy & Security

- **No network access** — whisper-cli runs fully on-device
- **No clipboard use** — text is typed directly; your clipboard is never read or written
- **No keylogging** — the app only records when explicitly triggered; it never listens passively
- **Local files only** — all data stays in `~/whisper-sessions/` and is auto-deleted
- **Minimal permissions** — requires Microphone and Accessibility (for Hammerspoon to type)
- **Open source** — all components are auditable

### Configuration (`~/.config/whisper-dictation/config`)

| Key | Default | Description |
|---|---|---|
| `WHISPER_MODEL` | `~/whisper-models/ggml-small.bin` | Path to whisper model file |
| `WHISPER_BIN` | auto-detected | Path to whisper-cli binary |
| `SESSIONS_DIR` | `~/whisper-sessions` | Where session audio/transcripts are stored |
| `SILENCE_DURATION_SEC` | `8` | Seconds of silence before auto-stop |
| `SESSION_RETENTION_COUNT` | `5` | How many past sessions to keep |

### Success Criteria (Gate A)

- ≥95% of dictation cycles complete successfully (recording → transcription → paste) across 30 consecutive uses
- Verified via `scripts/verify-reliability.sh` against `events.log`

---

## Out of Scope for MVP

- Wake word activation (e.g. "Hey Whisper")
- Continuous / always-on recording mode
- Cloud transcription fallback
- UI / menu bar interface
- Per-app paste behaviour customisation
- Punctuation commands ("new line", "period", etc.)
- Multi-language support beyond whisper model capability

---

## Future Ideas (v2+)

- [ ] Menu bar icon showing recording state (idle / recording / transcribing)
- [ ] Wake word trigger as alternative to Karabiner double-tap
- [ ] Smart punctuation: interpret spoken "period", "comma", "new line"
- [ ] Per-app profiles (e.g. use a different model for code editors)
- [ ] Configurable hotkey without requiring Karabiner
- [ ] Native paste using Accessibility API (AXUIElement) as a Hammerspoon alternative

---

## Dependencies

| Dependency | Why |
|---|---|
| Karabiner-Elements | Double-tap Control detection (macOS doesn't expose this natively) |
| whisper-cli (whisper.cpp) | Local on-device transcription |
| Hammerspoon | Typing text without clipboard, re-activating target app |
| macOS 13+ | AVAudioEngine API requirements |
