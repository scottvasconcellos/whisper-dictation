# Milestone: MVP — Auto-Paste Working

**Date:** 2026-02-16  
**Tag:** `checkpoint-auto-paste-working`  
**Status:** ✅ **WORKING** — This is the stable, tested version that successfully auto-pastes.

## What Works

- **Double-tap Control** → Ping sound → Recording starts
- **Single-tap Control** (or 8s silence) → Transcription → Clipboard set → Trigger file written → **Hammerspoon pastes (Cmd+V)** → Frog sound
- **No Accessibility prompts** — app never shows dialogs
- **Single paste path** — clipboard + trigger file only; Hammerspoon handles Cmd+V
- **Clean code** — no redundant fallbacks (CGEvent/AppleScript/AX removed)

## Architecture

- **WhisperDictation.app** (Swift): Records audio, transcribes via whisper-cli, sets clipboard, writes `~/.whisper-trigger/paste-request`
- **Hammerspoon** (`~/.hammerspoon/whisper-paste-watcher.lua`): Watches trigger file, sends Cmd+V, deletes file
- **Karabiner-Elements**: Double-tap/single-tap Control → triggers app via `~/bin/whisper-start.sh` / `whisper-stop.sh`

## Restore This Version

```bash
cd ~/Documents/My\ Apps/whisper-dictation
git checkout checkpoint-auto-paste-working
FORCE_REBUILD=1 bash install.sh
```

Then ensure Hammerspoon is running with the paste watcher (`~/.hammerspoon/init.lua` includes `require("whisper-paste-watcher")`).

## GitHub

- **Repo:** https://github.com/scottvasconcellos/whisper-dictation
- **Tag:** `checkpoint-auto-paste-working` (pushed)

## Notes for Future Agents

When the user says "the version that worked" or "MVP" or "milestone", they mean **this exact commit** (`checkpoint-auto-paste-working`). This is the baseline that auto-paste actually functions end-to-end. Any changes after this point should be tested against this checkpoint to ensure paste still works.
