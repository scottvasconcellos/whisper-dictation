#!/usr/bin/env bash
# Verification script for autopaste functionality
# Checks debug logs for paste success (AppleScript success + paste result success)
# Note: Accessibility is external one-time setup, not part of runtime verification

LOG_PATH="${HOME}/whisper-sessions/debug.log"

if [[ ! -f "$LOG_PATH" ]]; then
  echo "ERROR: Debug log not found at $LOG_PATH"
  echo "Please run at least one dictation cycle first"
  exit 1
fi

echo "=== Autopaste Verification Report ==="
echo ""

# Use Python to parse JSON logs properly
python3 << 'PYTHON_SCRIPT'
import json
import sys

import os
log_path = os.path.expanduser("~/whisper-sessions/debug.log")

try:
    with open(log_path, 'r') as f:
        lines = f.readlines()
except FileNotFoundError:
    print("ERROR: Log file not found")
    sys.exit(1)

cycles = []
current_cycle = []

for line in lines:
    try:
        entry = json.loads(line.strip())
        msg = entry.get('message', '')
        
        if msg == 'Transcript ready':
            if current_cycle:
                cycles.append(current_cycle)
            current_cycle = [entry]
        elif current_cycle:
            current_cycle.append(entry)
    except (json.JSONDecodeError, AttributeError):
        continue

if current_cycle:
    cycles.append(current_cycle)

if not cycles:
    print("⚠ No dictation cycles found in logs")
    print("Please run: double-tap Control, speak, single-tap Control")
    sys.exit(2)

failed_cycles = 0
passed_cycles = 0

for i, cycle in enumerate(cycles, 1):
    print(f"--- Cycle {i} ---")
    
    script_pass = False
    result_pass = False
    cycle_failed = False
    trust_info = None
    
    for entry in cycle:
        msg = entry.get('message', '')
        data = entry.get('data', {})
        
        if msg == 'Accessibility trust check':
            # Trust check is informational only (not a pass/fail criterion)
            trusted = data.get('trusted', False)
            trust_info = trusted
            if trusted:
                print("ℹ H1: Accessibility trusted: true (informational)")
            else:
                print("ℹ H1: Accessibility trusted: false (informational)")
        
        elif msg == 'Paste succeeded':
            attempt = data.get('attempt', 'unknown')
            print(f"✓ H2: Paste succeeded (attempt {attempt})")
            script_pass = True
        
        elif msg == 'Paste attempt failed':
            attempt = data.get('attempt', 'unknown')
            error_num = data.get('errorNumber', 'unknown')
            error_brief = data.get('errorBrief', '')
            is_final = data.get('attempt', 0) == data.get('maxAttempts', 3)
            if is_final:
                print(f"✗ H2: Paste failed after all attempts (attempt {attempt}, errorNumber: {error_num}) (FAIL)")
                script_pass = False
                cycle_failed = True
            else:
                print(f"⚠ H2: Paste attempt {attempt} failed, retrying (errorNumber: {error_num})")
        
        elif msg == 'Paste result':
            success = data.get('success', False)
            if success:
                print("✓ H4: Paste result success: true")
                result_pass = True
            else:
                print("✗ H4: Paste result success: false (FAIL)")
                result_pass = False
                cycle_failed = True
    
    if trust_info is None:
        print("ℹ H1: Trust check not found (informational only)")
    if not script_pass:
        print("? H2: AppleScript result not found")
    if not result_pass:
        print("? H4: Paste result not found")
    
    # Count cycle-level pass/fail: only H2 (AppleScript success) and H4 (paste result success) are required
    # H1 (trust check) is informational only, not a pass criterion
    if cycle_failed:
        failed_cycles += 1
    elif script_pass and result_pass:
        passed_cycles += 1
    
    print("")

print("=== Summary ===")
print(f"Total cycles analyzed: {len(cycles)}")
print(f"Cycles passed (all criteria): {passed_cycles}")
print(f"Cycles failed: {failed_cycles}")
print("")

if failed_cycles == 0 and passed_cycles > 0:
    print("✓ ALL ACCEPTANCE CRITERIA MET")
    print("Auto-paste is working correctly!")
    sys.exit(0)
else:
    print("✗ VERIFICATION FAILED")
    print("Some cycles did not meet acceptance criteria")
    sys.exit(1)
PYTHON_SCRIPT

EXIT_CODE=$?
exit $EXIT_CODE
