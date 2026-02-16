# WhisperDictation

macOS voice dictation using Whisper (whisper.cpp), Karabiner-Elements, and Hammerspoon. Double-tap Control to start recording, single-tap to stop; transcription is copied to clipboard and a trigger file tells Hammerspoon to paste (Cmd+V) at your cursor.

**Operator note:** During setup and verification, run all terminal commands yourself; do not ask the user to open Terminal.

**Restore point:** If you break something later, return to this working state:  
`cd ~/Documents/My\ Apps/whisper-dictation && git checkout checkpoint-auto-paste-working && FORCE_REBUILD=1 bash install.sh`

## How It Works

1. **Start:** Double-tap `Control` → Karabiner writes start trigger → WhisperDictation app plays Ping sound and starts recording
2. **Stop (manual):** Single-tap `Control` → app stops, transcribes, copies to clipboard, auto-pastes, plays Frog sound
3. **Stop (auto):** 8 seconds of silence → same flow as manual stop

**Manual stop always takes precedence** over silence stop if both occur simultaneously.

## Quick Start

```bash
cd ~/Documents/My\ Apps/whisper-dictation
bash install.sh
```

Then:
1. Add Karabiner rules from `karabiner/rules.json` to your Karabiner config
2. Grant Microphone and Automation permissions in System Settings
3. Test: Double-tap Control → speak → single-tap Control

## Requirements

- macOS (Apple Silicon or Intel)
- [whisper-cpp](https://github.com/ggerganov/whisper.cpp) (`brew install whisper-cpp`)
- GGML model (e.g. `ggml-small.bin`) in `~/whisper-models/`
- [Karabiner-Elements](https://karabiner-elements.pqrs.org/)
- [Hammerspoon](https://www.hammerspoon.org/) for auto-paste (`brew install --cask hammerspoon`) + paste watcher (see `docs/HAMMERSPOON_PASTE.md`)

## Verification

After running dictation cycles, verify reliability:

```bash
bash scripts/verify-reliability.sh
```

This checks:
- Manual stop success (AT1)
- Silence stop success (AT2)
- Manual precedence (AT3)
- Double-tap ignored during recording (AT4)
- Paste failure retry behavior (AT5)
- Overall success rate across 30+ cycles (AT6)
- Latency metrics P50/P95 (AT7)

**Gate A Criteria:** >=95% successful auto-paste across 30 cycles

## Project Structure

```
whisper-dictation/
├── config.example              # Config template
├── install.sh                  # Installer (builds app, symlinks scripts)
├── scripts/
│   ├── whisper-start.sh       # Thin trigger emitter (start)
│   ├── whisper-stop.sh        # Thin trigger emitter (stop)
│   ├── common.sh              # Shared config/logging
│   └── verify-reliability.sh  # Acceptance test runner
├── karabiner/
│   └── rules.json             # Karabiner rule (absolute paths)
├── WhisperDictation/          # Swift app source
│   ├── AppDelegate.swift      # State machine + orchestration
│   ├── Recorder.swift         # Audio capture + silence detection
│   ├── EventLogger.swift      # Canonical event logging
│   └── build.sh               # Build script
└── LaunchAgents/
    └── com.whisper.dictation.plist
```

## Release Gates

- **Gate A (Core + Skeleton DMG):** Reliable core flow with >=95% success rate → early testable DMG
- **Gate B (Polish DMG):** Native UI polish + model management UX + final packaging

## Troubleshooting

- **Double-tap does nothing:** Check Karabiner rules are active and scripts are in `~/bin`
- **No auto-paste:** Install Hammerspoon, add the paste watcher (`docs/HAMMERSPOON_PASTE.md`), grant it Accessibility, and reload config
- **No sound:** Check Microphone permission
- **Events log:** Check `~/whisper-sessions/events.log` for detailed event history
