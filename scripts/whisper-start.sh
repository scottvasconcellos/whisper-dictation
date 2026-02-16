#!/usr/bin/env bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# Ensure dirs exist (app creates session dir when it starts recording)
mkdir -p "$SESSIONS_DIR"
mkdir -p "$TRIGGER_DIR"

# Write start trigger only; WhisperDictation app handles session creation
touch "$RECORD_START_TRIGGER"
log "Start trigger: $RECORD_START_TRIGGER"
# Optional: show notification so you can confirm double-tap reached the script (set TRIGGER_TEST=1 in config)
if [[ "${TRIGGER_TEST:-0}" == "1" ]]; then
  osascript -e 'display notification "Start trigger ran" with title "Whisper"' 2>/dev/null || true
fi