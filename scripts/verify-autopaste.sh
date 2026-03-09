#!/usr/bin/env bash
# Verification script for autopaste functionality
# Reads events.log and checks each cycle for transcription_complete + paste_triggered

LOG_PATH="${HOME}/whisper-sessions/events.log"

if [[ ! -f "$LOG_PATH" ]]; then
  echo "ERROR: Events log not found at $LOG_PATH"
  echo "Please run at least one dictation cycle first"
  exit 1
fi

echo "=== Autopaste Verification Report ==="
echo ""

python3 << 'PYTHON_SCRIPT'
import json
import os
import sys
from collections import defaultdict

log_path = os.path.expanduser("~/whisper-sessions/events.log")

try:
    with open(log_path, 'r') as f:
        lines = f.readlines()
except FileNotFoundError:
    print("ERROR: Log file not found")
    sys.exit(1)

events = []
for line in lines:
    try:
        events.append(json.loads(line.strip()))
    except json.JSONDecodeError:
        continue

sessions = defaultdict(list)
for event in events:
    session_id = event.get("sessionId", "")
    if session_id:
        sessions[session_id].append(event)

if not sessions:
    print("⚠ No dictation cycles found in logs")
    print("Please run: double-tap Control, speak, single-tap Control")
    sys.exit(2)

passed_cycles = 0
failed_cycles = 0

for i, (session_id, session_events) in enumerate(sorted(sessions.items()), 1):
    print(f"--- Cycle {i} ({session_id}) ---")
    started = any(e.get("event") == "recording_started" for e in session_events)
    transcribed = any(e.get("event") == "transcription_complete" for e in session_events)
    triggered = any(e.get("event") == "paste_triggered" for e in session_events)
    errors = [e.get("message") for e in session_events if e.get("event") == "error"]

    if started:
        print("✓ Recording started")
    if transcribed:
        text_len = next((e.get("textLength", 0) for e in session_events if e.get("event") == "transcription_complete"), 0)
        print(f"✓ Transcription complete ({text_len} chars)")
    else:
        print("✗ Transcription did not complete")
    if triggered:
        lat = next((e.get("latencyMs") for e in session_events if e.get("event") == "paste_triggered"), None)
        lat_str = f" ({lat}ms)" if lat else ""
        print(f"✓ Paste triggered{lat_str}")
    else:
        print("✗ Paste trigger not written")
    if errors:
        for err in errors:
            print(f"  ⚠ error: {err}")

    if transcribed and triggered:
        passed_cycles += 1
    else:
        failed_cycles += 1
    print("")

total = passed_cycles + failed_cycles
print("=== Summary ===")
print(f"Total cycles analyzed: {total}")
print(f"Cycles passed: {passed_cycles}")
print(f"Cycles failed: {failed_cycles}")
print("")

if total == 0:
    sys.exit(2)
elif failed_cycles == 0 and passed_cycles > 0:
    print("✓ ALL ACCEPTANCE CRITERIA MET")
    print("Auto-paste is working correctly!")
    sys.exit(0)
else:
    print("✗ VERIFICATION FAILED")
    print("Some cycles did not complete transcription + paste trigger")
    sys.exit(1)
PYTHON_SCRIPT

EXIT_CODE=$?
exit $EXIT_CODE
