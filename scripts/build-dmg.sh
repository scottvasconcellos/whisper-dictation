#!/usr/bin/env bash
# Build DMG for WhisperDictation
# Creates a testable skeleton DMG (Gate A) or polished DMG (Gate B)

set -e

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="WhisperDictation"
APP_PATH="${REPO}/WhisperDictation/build/${APP_NAME}.app"
DMG_NAME="${APP_NAME}"
VERSION="${1:-skeleton}"  # "skeleton" for Gate A, version number for Gate B
DMG_PATH="${REPO}/${DMG_NAME}-${VERSION}.dmg"
DMG_TEMP_DIR="${REPO}/.dmg-build"

echo "Building DMG: ${DMG_NAME}-${VERSION}.dmg"
echo ""

# Ensure app is built
if [[ ! -d "$APP_PATH" ]]; then
    echo "ERROR: App not found at $APP_PATH"
    echo "Run: bash install.sh first"
    exit 1
fi

# Clean up temp dir
rm -rf "$DMG_TEMP_DIR"
mkdir -p "$DMG_TEMP_DIR"

# Copy app to temp dir
cp -R "$APP_PATH" "$DMG_TEMP_DIR/"

# Create Applications symlink
ln -s /Applications "$DMG_TEMP_DIR/Applications"

# Create README
cat > "$DMG_TEMP_DIR/README.txt" << EOF
WhisperDictation ${VERSION}

INSTALLATION:
1. Drag WhisperDictation.app to Applications folder
2. Open Applications → WhisperDictation.app
3. Grant Microphone and Automation permissions when prompted
4. Add Karabiner rules from the project's karabiner/rules.json
5. Test: Double-tap Control → speak → single-tap Control

REQUIREMENTS:
- macOS (Apple Silicon or Intel)
- whisper-cpp (brew install whisper-cpp)
- Whisper model in ~/whisper-models/ (e.g., ggml-small.bin)
- Karabiner-Elements

For full setup instructions, see the project repository.
EOF

# Create DMG
echo "Creating DMG..."
hdiutil create -volname "$APP_NAME" \
    -srcfolder "$DMG_TEMP_DIR" \
    -ov -format UDZO \
    "$DMG_PATH" > /dev/null

# Clean up
rm -rf "$DMG_TEMP_DIR"

echo ""
echo "✓ DMG created: $DMG_PATH"
echo ""
echo "To test:"
echo "  open \"$DMG_PATH\""
