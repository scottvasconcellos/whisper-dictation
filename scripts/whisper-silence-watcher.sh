#!/usr/bin/env bash
# Watches FFmpeg stderr for silence_start (8s silence reached), then runs whisper-stop.sh
# Note: silence_start fires when the configured duration is reached; silence_end fires when sound resumes.

SESSION_DIR="$1"
if [[ -z "$SESSION_DIR" || ! -d "$SESSION_DIR" ]]; then
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

FFMPEG_LOG="${SESSION_DIR}/ffmpeg.log"
FFMPEG_PID_FILE="${SESSION_DIR}/ffmpeg.pid"

# Wait for log file to exist
for i in {1..50}; do
  [[ -f "$FFMPEG_LOG" ]] && break
  sleep 0.1
done
[[ ! -f "$FFMPEG_LOG" ]] && exit 1

# Tail -f and watch for silence_start (8s silence reached)
# Do NOT kill FFmpeg here; whisper-stop.sh will kill it, sleep 0.5, then transcribe.
while IFS= read -r line; do
  if [[ "$line" == *"silence_start"* ]]; then
    log "Silence detected (8s), running whisper-stop"
    "${SCRIPT_DIR}/whisper-stop.sh"
    exit 0
  fi
done < <(tail -f "$FFMPEG_LOG" 2>/dev/null)
