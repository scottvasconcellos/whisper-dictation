# Whisper Dictation — running again

Restored the **checkpoint-auto-paste-working** version and got it running.

## What’s done

- **WhisperDictation.app** — built and **running** (opened by install).
- **Scripts** — `~/bin/whisper-start.sh` and `~/bin/whisper-stop.sh` linked from the repo.
- **LaunchAgent** — `com.whisper.dictation` installed; the app will start at login (it’s already running now).
- **Karabiner** — Whisper rule in your config is **enabled** and uses full paths so double-tap/single-tap Control run the scripts.
- **Hammerspoon** — your existing `whisper-paste-watcher.lua` is used for auto-paste (no change needed).

## How to use

1. Put the cursor where you want the text.
2. **Double-tap Control** → Ping sound → recording starts.
3. Speak (or wait; 8 seconds of silence also stops).
4. **Single-tap Control** → Frog sound → transcribe, copy, auto-paste.

## If double-tap / single-tap don’t work

- Open **Karabiner-Elements** so it reloads the config (the Whisper rule is now enabled).
- Confirm **Microphone** and **Automation** (System Events) are allowed for **WhisperDictation** in System Settings → Privacy & Security.

## Restore this version again later

```bash
cd ~/Documents/My\ Apps/whisper-dictation
git checkout checkpoint-auto-paste-working
FORCE_REBUILD=1 bash install.sh
```

Then enable the Whisper rule in Karabiner and ensure Hammerspoon is running with the paste watcher.
