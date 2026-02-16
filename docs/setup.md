# WhisperDictation Setup Guide

## Prerequisites

1. Install whisper-cpp:
   ```bash
   brew install whisper-cpp
   ```

2. Download a Whisper model (e.g., `ggml-small.bin`) to `~/whisper-models/`:
   ```bash
   mkdir -p ~/whisper-models
   # Download from https://huggingface.co/ggerganov/whisper.cpp
   ```

3. Install Karabiner-Elements:
   - Download from https://karabiner-elements.pqrs.org/
   - Complete initial setup

## Installation

1. Run the installer:
   ```bash
   cd ~/Documents/My\ Apps/whisper-dictation
   bash install.sh
   ```

2. Add Karabiner rules:
   - Open Karabiner-Elements → Complex Modifications → Rules
   - Import `karabiner/rules.json` (or copy the rule manually)
   - Enable the "Whisper Dictation" rule

3. Grant permissions:
   - **Microphone:** System Settings → Privacy & Security → Microphone → Enable WhisperDictation
   - **Automation:** System Settings → Privacy & Security → Automation → Enable WhisperDictation → System Events

4. Start the app:
   ```bash
   launchctl load ~/Library/LaunchAgents/com.whisper.dictation.plist
   ```

## Testing

1. **Basic test:**
   - Double-tap `Control` (should hear Ping)
   - Speak clearly
   - Single-tap `Control` (should hear Frog, text pasted)

2. **Silence test:**
   - Double-tap `Control`
   - Speak, then remain silent for 8 seconds
   - Should auto-stop and paste

3. **Verification:**
   ```bash
   bash scripts/verify-reliability.sh
   ```

## Configuration

Edit `~/.config/whisper-dictation/config`:

```
WHISPER_MODEL=~/whisper-models/ggml-small.bin
WHISPER_BIN=/opt/homebrew/bin/whisper-cli
SILENCE_DURATION_SEC=8
SESSION_RETENTION_DAYS=7
```

## Troubleshooting

### Double-tap does nothing
- Verify Karabiner rule is enabled
- Check scripts exist: `ls ~/bin/whisper-*.sh`
- Test trigger manually: `touch ~/.whisper-trigger/record-start`

### No auto-paste
- Check Automation permission (System Settings)
- Verify app is running: `ps aux | grep WhisperDictation`
- Check events log: `tail -f ~/whisper-sessions/events.log`

### No sound
- Check Microphone permission
- Verify system sounds: `afplay /System/Library/Sounds/Ping.aiff`

### App won't start
- Check LaunchAgent: `launchctl list | grep whisper`
- Restart manually: `pkill -f WhisperDictation && open -n ~/Documents/My\ Apps/whisper-dictation/WhisperDictation/build/WhisperDictation.app`

## Acceptance Tests

The verification script checks:
- **AT1:** Manual stop succeeds
- **AT2:** Silence stop succeeds  
- **AT3:** Manual stop takes precedence
- **AT4:** Double-tap during recording is ignored
- **AT5:** Paste failure retries once, keeps clipboard
- **AT6:** >=95% success rate across 30 cycles
- **AT7:** Latency P50<=450ms, P95<=800ms

## Gate A Criteria

To pass Gate A (skeleton DMG release):
- Run 30+ dictation cycles
- Achieve >=95% successful auto-paste rate
- Verify all acceptance tests pass

Run verification:
```bash
bash scripts/verify-reliability.sh
```
