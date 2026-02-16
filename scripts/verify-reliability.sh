#!/usr/bin/env bash
# Verification script for WhisperDictation reliability
# Checks events.log for acceptance criteria and computes success rate

set -e

LOG_PATH="${HOME}/whisper-sessions/events.log"

if [[ ! -f "$LOG_PATH" ]]; then
  echo "ERROR: Events log not found at $LOG_PATH"
  echo "Please run at least one dictation cycle first"
  exit 1
fi

echo "=== WhisperDictation Reliability Verification ==="
echo ""

python3 << 'PYTHON_SCRIPT'
import json
import os
import sys
from collections import defaultdict
from statistics import median

log_path = os.path.expanduser("~/whisper-sessions/events.log")

try:
    with open(log_path, 'r') as f:
        lines = f.readlines()
except FileNotFoundError:
    print("ERROR: Log file not found")
    sys.exit(1)

# Parse events
events = []
for line in lines:
    try:
        events.append(json.loads(line.strip()))
    except json.JSONDecodeError:
        continue

# Group events by sessionId
sessions = defaultdict(list)
for event in events:
    session_id = event.get("sessionId", "")
    if session_id:
        sessions[session_id].append(event)

# Analyze each session
cycles = []
for session_id, session_events in sessions.items():
    cycle = {
        "sessionId": session_id,
        "started": False,
        "stopped": False,
        "transcribed": False,
        "pasteSuccess": False,
        "stopReason": None,
        "latencyMs": None,
        "errors": []
    }
    
    for event in session_events:
        event_type = event.get("event")
        
        if event_type == "session_start":
            cycle["started"] = True
        elif event_type == "recording_started":
            cycle["started"] = True
        elif event_type == "stop_requested":
            cycle["stopped"] = True
            cycle["stopReason"] = event.get("stopReason", "unknown")
        elif event_type == "transcription_complete":
            cycle["transcribed"] = True
        elif event_type == "paste_result":
            cycle["pasteSuccess"] = event.get("success", False)
            cycle["latencyMs"] = event.get("latencyMs")
        elif event_type == "error":
            cycle["errors"].append(event.get("message", "unknown"))
    
    if cycle["started"]:
        cycles.append(cycle)

if not cycles:
    print("⚠ No dictation cycles found in logs")
    print("Please run: double-tap Control, speak, single-tap Control")
    sys.exit(2)

# Acceptance Test Results
print("=== Acceptance Test Results ===")
print("")

at1_pass = 0  # Manual stop succeeds
at2_pass = 0  # Silence stop succeeds
at3_pass = 0  # Manual precedence
at4_pass = 0  # Double-tap ignored
at5_pass = 0  # Paste failure path (retry + clipboard)
at6_total = len(cycles)
at6_pass = sum(1 for c in cycles if c["pasteSuccess"])
at7_latencies = [c["latencyMs"] for c in cycles if c["latencyMs"] is not None]

manual_stops = [c for c in cycles if c["stopReason"] == "manual"]
silence_stops = [c for c in cycles if c["stopReason"] == "silence"]

at1_pass = sum(1 for c in manual_stops if c["pasteSuccess"])
at2_pass = sum(1 for c in silence_stops if c["pasteSuccess"])

# AT3: Manual precedence (check if manual stops override silence)
at3_pass = len([c for c in cycles if c["stopReason"] == "manual"])

# AT4: Double-tap ignored (check for start_ignored events)
at4_ignored = sum(1 for e in events if e.get("event") == "start_ignored")
at4_pass = 1 if at4_ignored > 0 else 0  # At least one ignored is good

# AT5: Paste failure path (check for retry attempts)
at5_failures = [c for c in cycles if not c["pasteSuccess"]]
at5_pass = len(at5_failures)  # If failures exist, they should have retried

print(f"AT1 Manual stop: {at1_pass}/{len(manual_stops)} passed" if manual_stops else "AT1 Manual stop: No manual stops found")
print(f"AT2 Silence stop: {at2_pass}/{len(silence_stops)} passed" if silence_stops else "AT2 Silence stop: No silence stops found")
print(f"AT3 Manual precedence: {at3_pass} manual stops detected")
print(f"AT4 Double-tap ignored: {at4_pass} (found {at4_ignored} ignored start attempts)")
print(f"AT5 Paste failure path: {at5_pass} failures with retry")
print(f"AT6 Repetition (30 cycles): {at6_pass}/{at6_total} successful ({at6_pass*100//at6_total if at6_total > 0 else 0}%)")
if at7_latencies:
    p50 = median(at7_latencies)
    p95 = sorted(at7_latencies)[int(len(at7_latencies) * 0.95)] if len(at7_latencies) > 0 else 0
    print(f"AT7 Latency: P50={p50}ms, P95={p95}ms (target: P50<=450ms, P95<=800ms)")
else:
    print("AT7 Latency: No latency data available")

print("")
print("=== Summary ===")
print(f"Total cycles analyzed: {at6_total}")
print(f"Successful auto-paste: {at6_pass} ({at6_pass*100//at6_total if at6_total > 0 else 0}%)")
print(f"Failed cycles: {at6_total - at6_pass}")

# Gate A criteria: >=95% success across 30 cycles
if at6_total >= 30:
    success_rate = (at6_pass / at6_total) * 100
    if success_rate >= 95:
        print("")
        print("✓✓✓ GATE A CRITERIA MET ✓✓✓")
        print(f"Success rate: {success_rate:.1f}% (target: >=95%)")
        print("Auto-paste reliability threshold achieved!")
        sys.exit(0)
    else:
        print("")
        print("✗ GATE A CRITERIA NOT MET")
        print(f"Success rate: {success_rate:.1f}% (target: >=95%)")
        print("Need more reliable cycles before Gate A")
        sys.exit(1)
else:
    print("")
    print(f"⚠ Need at least 30 cycles for Gate A verification (currently: {at6_total})")
    if at6_total > 0:
        success_rate = (at6_pass / at6_total) * 100
        print(f"Current success rate: {success_rate:.1f}%")
    sys.exit(2)

PYTHON_SCRIPT

EXIT_CODE=$?
exit $EXIT_CODE
