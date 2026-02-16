#!/usr/bin/env bash
# Trust Doctor: Diagnose and remediate Accessibility trust issues

APP_PATH="/Users/scottvasconcellos/Documents/My Apps/whisper-dictation/WhisperDictation/build/WhisperDictation.app"
BUNDLE_ID="com.whisper.dictation"

echo "=== Trust Doctor: Accessibility Trust Diagnosis ==="
echo ""

# 1. Check app signature
echo "1. Checking app signature..."
cdhash=$(codesign -d -r- "$APP_PATH" 2>&1 | grep "cdhash" | sed 's/.*cdhash H"\([^"]*\)".*/\1/')
if [[ -n "$cdhash" ]]; then
  echo "   ✓ App cdhash: $cdhash"
else
  echo "   ✗ Could not read app signature"
  exit 1
fi

# 2. Check TCC database
echo ""
echo "2. Checking TCC database..."
TCC_RESULT=$(sqlite3 "/Library/Application Support/com.apple.TCC/TCC.db" \
  "SELECT service,client,auth_value,auth_reason FROM access WHERE service='kTCCServiceAccessibility' AND client='$BUNDLE_ID';" 2>&1)

if echo "$TCC_RESULT" | grep -q "$BUNDLE_ID"; then
  AUTH_VALUE=$(echo "$TCC_RESULT" | cut -d'|' -f3)
  if [[ "$AUTH_VALUE" == "2" ]]; then
    echo "   ✓ TCC shows Accessibility: ALLOWED (auth_value=2)"
  else
    echo "   ⚠ TCC shows Accessibility: DENIED (auth_value=$AUTH_VALUE)"
  fi
else
  echo "   ✗ No TCC entry found for $BUNDLE_ID"
fi

# 3. Check if app is running
echo ""
echo "3. Checking app process..."
if pgrep -f "WhisperDictation.app/Contents/MacOS/WhisperDictation" > /dev/null; then
  echo "   ✓ App is running"
  APP_RUNNING=true
else
  echo "   ⚠ App is not running"
  APP_RUNNING=false
fi

# 4. Test runtime trust check (requires app to be running)
echo ""
echo "4. Runtime trust check..."
if [[ "$APP_RUNNING" == "true" ]]; then
  # Use osascript to check if app can send keystrokes
  TRUST_TEST=$(osascript -e 'tell application "System Events" to keystroke "v" using command down' 2>&1)
  if [[ $? -eq 0 ]]; then
    echo "   ✓ Runtime test: App can send keystrokes"
  else
    echo "   ✗ Runtime test: App cannot send keystrokes"
    echo "   Error: $TRUST_TEST"
  fi
else
  echo "   ⚠ Skipped (app not running)"
fi

# 5. Recommendations
echo ""
echo "=== Recommendations ==="
if [[ "$AUTH_VALUE" != "2" ]]; then
  echo "1. Grant Accessibility permission:"
  echo "   System Settings > Privacy & Security > Accessibility"
  echo "   Enable toggle for 'WhisperDictation'"
  echo ""
fi

if [[ "$APP_RUNNING" == "false" ]]; then
  echo "2. Restart the app:"
  echo "   pkill -f WhisperDictation && open -n \"$APP_PATH\""
  echo ""
fi

if [[ "$AUTH_VALUE" == "2" && "$APP_RUNNING" == "true" ]]; then
  echo "⚠ TCC shows allowed but runtime check may fail."
  echo "   This can happen if:"
  echo "   - App signature changed (cdhash mismatch)"
  echo "   - App needs restart after permission grant"
  echo ""
  echo "   Try:"
  echo "   1. Reset TCC: sudo tccutil reset Accessibility $BUNDLE_ID"
  echo "   2. Restart app"
  echo "   3. Grant permission again when prompted"
fi

echo ""
echo "=== Next Steps ==="
echo "After fixing permissions, run verification:"
echo "  bash scripts/verify-autopaste.sh"
