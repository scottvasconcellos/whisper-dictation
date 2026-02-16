#!/usr/bin/env bash
# Install Whisper Dictation: create dirs, symlink scripts, build WhisperDictation.app, install LaunchAgent

set -e
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Installing Whisper Dictation from $REPO"

# 1. Create dirs
mkdir -p ~/bin
mkdir -p ~/whisper-sessions
mkdir -p ~/whisper-models
mkdir -p ~/.whisper-trigger
mkdir -p ~/.config/whisper-dictation

# 2. Copy config if missing
if [[ ! -f ~/.config/whisper-dictation/config ]]; then
  cp "$REPO/config.example" ~/.config/whisper-dictation/config
  echo "Created ~/.config/whisper-dictation/config"
else
  echo "Config exists, skipped"
fi

# 3. Symlink scripts to ~/bin (only whisper-start, whisper-stop, common)
for script in whisper-start.sh whisper-stop.sh common.sh; do
  src="$REPO/scripts/$script"
  dst="$HOME/bin/$script"
  if [[ -f "$src" ]]; then
    ln -sf "$src" "$dst"
    chmod +x "$src"
    echo "Linked $dst -> $src"
  fi
done

# 3b. Generate Karabiner rule with absolute paths (so it works even if Karabiner's env has no HOME)
RULES_SRC="$REPO/karabiner/rules.json"
RULES_ABS="$REPO/karabiner/rules-absolute.json"
if [[ -f "$RULES_SRC" ]]; then
  sed "s|\$HOME|$HOME|g" "$RULES_SRC" > "$RULES_ABS"
  echo "Generated karabiner/rules-absolute.json (use this in Karabiner if double-tap does not run the script)"
fi

# 4. Build WhisperDictation.app only when needed.
# Rebuilding an ad-hoc signed app changes code hash and can invalidate Accessibility trust.
WHISPER_APP="$REPO/WhisperDictation/build/WhisperDictation.app"
WHISPER_BIN="$WHISPER_APP/Contents/MacOS/WhisperDictation"
FORCE_REBUILD="${FORCE_REBUILD:-0}"

NEED_BUILD=0
if [[ ! -x "$WHISPER_BIN" ]]; then
  NEED_BUILD=1
fi

if [[ "$FORCE_REBUILD" == "1" ]]; then
  NEED_BUILD=1
fi

if [[ "$NEED_BUILD" == "0" ]]; then
  for src in \
    "$REPO/WhisperDictation/main.swift" \
    "$REPO/WhisperDictation/Config.swift" \
    "$REPO/WhisperDictation/EventLogger.swift" \
    "$REPO/WhisperDictation/SoundHelper.swift" \
    "$REPO/WhisperDictation/Recorder.swift" \
    "$REPO/WhisperDictation/AppDelegate.swift" \
    "$REPO/WhisperDictation/Info.plist" \
    "$REPO/WhisperDictation/build.sh"; do
    if [[ "$src" -nt "$WHISPER_BIN" ]]; then
      NEED_BUILD=1
      break
    fi
  done
fi

if [[ "$NEED_BUILD" == "1" ]]; then
  echo "Building WhisperDictation.app..."
  bash "$REPO/WhisperDictation/build.sh"
else
  echo "WhisperDictation.app is up to date; skipping rebuild to preserve Accessibility trust."
fi

if [[ ! -d "$WHISPER_APP" ]]; then
  echo "Warning: WhisperDictation.app build may have failed. Run: bash $REPO/WhisperDictation/build.sh"
fi

# 5. Install LaunchAgent for WhisperDictation
LAUNCH_AGENT_DST="$HOME/Library/LaunchAgents/com.whisper.dictation.plist"
LAUNCH_AGENT_SRC="$REPO/LaunchAgents/com.whisper.dictation.plist"

if [[ -d "$WHISPER_APP" ]]; then
  if [[ -x "$WHISPER_APP/Contents/MacOS/WhisperDictation" ]]; then
    sed "s|APP_PATH_PLACEHOLDER|$WHISPER_APP|g" "$LAUNCH_AGENT_SRC" > "$LAUNCH_AGENT_DST"
    echo "Installed LaunchAgent: $LAUNCH_AGENT_DST"
    echo "  To start: launchctl load $LAUNCH_AGENT_DST"
    echo "  To stop:  launchctl unload $LAUNCH_AGENT_DST"
  fi
else
  echo "Skipping LaunchAgent (WhisperDictation.app not built)"
fi

# 6. Restart the app binary explicitly.
# With open-based LaunchAgent, unload/load does not terminate an already-running app process.
if [[ -x "$WHISPER_BIN" ]]; then
  pkill -f "$WHISPER_BIN" 2>/dev/null || true
  open -n "$WHISPER_APP"
  echo "Restarted WhisperDictation app: $WHISPER_APP"
fi

echo ""
echo "=== Setup checklist ==="
echo "1. Install whisper-cpp:  brew install whisper-cpp"
echo "2. Download model:      ggml-small.bin to ~/whisper-models/"
echo "   From: https://huggingface.co/ggerganov/whisper.cpp"
echo "3. Add Karabiner rules: See karabiner/rules.json and docs/SETUP.md"
echo "4. Grant Microphone:    System Settings > Privacy & Security > Microphone — allow WhisperDictation"
echo "5. Grant Automation:    System Settings > Privacy & Security > Automation — allow WhisperDictation to control System Events"
echo "6. Test: Double-tap Control (Ping), speak, single-tap Control (Frog, paste)"
echo ""
echo "=== Verification ==="
echo "After testing, verify reliability:"
echo "  bash scripts/verify-reliability.sh"
echo ""
echo "=== Build DMG ==="
echo "Once Gate A criteria met (>=95% success across 30 cycles):"
echo "  bash scripts/build-dmg.sh skeleton"
echo ""
