#!/usr/bin/env bash
# Operator workflow: Full verification cycle for autopaste
# Assistant runs this; user only performs system settings clicks

APP_PATH="/Users/scottvasconcellos/Documents/My Apps/whisper-dictation/WhisperDictation/build/WhisperDictation.app"
REPO="/Users/scottvasconcellos/Documents/My Apps/whisper-dictation"

echo "=== Operator Verification Workflow ==="
echo ""

# Step 1: Ensure app is built and up to date
echo "Step 1: Checking installer..."
cd "$REPO"
bash install.sh > /dev/null 2>&1
echo "   ✓ Installer completed"

# Step 2: Run trust doctor
echo ""
echo "Step 2: Running trust diagnosis..."
bash "$REPO/scripts/trust-doctor.sh"

# Step 3: Restart app cleanly
echo ""
echo "Step 3: Restarting app..."
pkill -f "WhisperDictation.app/Contents/MacOS/WhisperDictation" 2>/dev/null || true
sleep 2
open -n "$APP_PATH"
sleep 3
echo "   ✓ App restarted"

# Step 4: Clear old logs
echo ""
echo "Step 4: Clearing old logs..."
LOG_PATH="${HOME}/whisper-sessions/debug.log"
if [[ -f "$LOG_PATH" ]]; then
  > "$LOG_PATH"
  echo "   ✓ Logs cleared"
else
  echo "   ⚠ Log file doesn't exist yet (will be created on first cycle)"
fi

# Step 5: User instructions
echo ""
echo "=== USER ACTION REQUIRED ==="
echo ""
echo "Please run at least 2 dictation cycles:"
echo ""
echo "1. Double-tap Control key (hear ping sound)"
echo "2. Speak clearly"
echo "3. Single-tap Control key (hear frog sound)"
echo "4. Repeat once more"
echo ""
echo "Note: If auto-paste fails, text is copied to clipboard and a notification will appear."
echo "      You can paste manually with Cmd+V."
echo ""
echo "When done, press ENTER here to continue verification..."
read -r

# Step 6: Run verification
echo ""
echo "=== Running Verification ==="
bash "$REPO/scripts/verify-autopaste.sh"
VERIFY_EXIT=$?

if [[ $VERIFY_EXIT -eq 0 ]]; then
  echo ""
  echo "✓✓✓ VERIFICATION PASSED ✓✓✓"
  echo "Auto-paste is working correctly!"
  exit 0
else
  echo ""
  echo "✗ VERIFICATION FAILED"
  echo ""
  echo "Some cycles did not meet acceptance criteria."
  echo "Check logs for details. Text is still copied to clipboard for manual pasting."
  exit 1
fi
