#!/usr/bin/env bash
# Common helpers for Whisper Dictation scripts.
# Source this at the top of whisper-start.sh, whisper-stop.sh, whisper-silence-watcher.sh.

# Karabiner may run with minimal env; ensure HOME is set
export HOME="${HOME:-$(eval echo ~)}"

# Config paths (try both locations)
CONFIG_XDG="${HOME}/.config/whisper-dictation/config"
CONFIG_LEGACY="${HOME}/.whisper-dictation/config"
if [[ -f "$CONFIG_XDG" ]]; then
  CONFIG="$CONFIG_XDG"
elif [[ -f "$CONFIG_LEGACY" ]]; then
  CONFIG="$CONFIG_LEGACY"
else
  CONFIG=""
fi

# Defaults
MIC_INDEX=0
WHISPER_MODEL="${HOME}/whisper-models/ggml-small.bin"
WHISPER_BIN=""
SESSIONS_DIR="${HOME}/whisper-sessions"
TRIGGER_DIR="${HOME}/.whisper-trigger"
RECORD_START_TRIGGER=""
RECORD_STOP_TRIGGER=""
SILENCE_THRESHOLD_DB=-35
SILENCE_DURATION_SEC=8
SESSION_RETENTION_DAYS=7
TRIGGER_TEST=0

# Load config if present
if [[ -n "$CONFIG" ]]; then
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z "$line" || "$line" != *=* ]] && continue
    key="${line%%=*}"
    key="${key%"${key##*[![:space:]]}"}"
    val="${line#*=}"
    val="${val#"${val%%[![:space:]]*}"}"
    val="${val//\~/$HOME}"
    case "$key" in
      MIC_INDEX) MIC_INDEX="$val" ;;
      WHISPER_MODEL) WHISPER_MODEL="$val" ;;
      WHISPER_BIN) WHISPER_BIN="$val" ;;
      SESSIONS_DIR) SESSIONS_DIR="$val" ;;
      TRIGGER_DIR) TRIGGER_DIR="$val" ;;
      RECORD_START_TRIGGER) RECORD_START_TRIGGER="$val" ;;
      RECORD_STOP_TRIGGER) RECORD_STOP_TRIGGER="$val" ;;
      SILENCE_THRESHOLD_DB) SILENCE_THRESHOLD_DB="$val" ;;
      SILENCE_DURATION_SEC) SILENCE_DURATION_SEC="$val" ;;
      SESSION_RETENTION_DAYS) SESSION_RETENTION_DAYS="$val" ;;
      TRIGGER_TEST) TRIGGER_TEST="$val" ;;
    esac
  done < "$CONFIG"
fi

# Detect whisper-cli if not set
if [[ -z "$WHISPER_BIN" ]]; then
  if command -v whisper-cli &>/dev/null; then
    WHISPER_BIN="$(command -v whisper-cli)"
  elif [[ -x /opt/homebrew/bin/whisper-cli ]]; then
    WHISPER_BIN=/opt/homebrew/bin/whisper-cli
  elif [[ -x /usr/local/bin/whisper-cli ]]; then
    WHISPER_BIN=/usr/local/bin/whisper-cli
  fi
fi

# Expand ~ in paths
SESSIONS_DIR="${SESSIONS_DIR//\~/$HOME}"
# Force canonical trigger path: always ~/.whisper-trigger (ignore config) so app and scripts never disagree
TRIGGER_DIR="${HOME}/.whisper-trigger"
RECORD_START_TRIGGER="${HOME}/.whisper-trigger/record-start"
RECORD_STOP_TRIGGER="${HOME}/.whisper-trigger/record-stop"
WHISPER_MODEL="${WHISPER_MODEL//\~/$HOME}"

# Script dir (for finding whisper-silence-watcher.sh)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="${HOME}/bin"

log() {
  mkdir -p "$SESSIONS_DIR"
  echo "$(date '+%Y-%m-%d %H:%M:%S') $*" >> "${SESSIONS_DIR}/whisper-debug.log"
}

play_sound() {
  local name="$1"
  afplay "/System/Library/Sounds/${name}.aiff" 2>/dev/null || true
}

play_error() {
  play_sound "Basso"
}
