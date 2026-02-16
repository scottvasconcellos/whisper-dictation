#!/usr/bin/env bash
# Build WhisperDictation.app (no Xcode required, only swiftc)

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_APP="${SCRIPT_DIR}/build/WhisperDictation.app"

mkdir -p "${OUTPUT_APP}/Contents/MacOS"
mkdir -p "${OUTPUT_APP}/Contents/Resources"

swiftc -o "${OUTPUT_APP}/Contents/MacOS/WhisperDictation" \
  -framework AppKit \
  -framework Foundation \
  -framework AVFoundation \
  -framework CoreMedia \
  "${SCRIPT_DIR}/main.swift" \
  "${SCRIPT_DIR}/Config.swift" \
  "${SCRIPT_DIR}/EventLogger.swift" \
  "${SCRIPT_DIR}/SoundHelper.swift" \
  "${SCRIPT_DIR}/Recorder.swift" \
  "${SCRIPT_DIR}/AppDelegate.swift"

cp "${SCRIPT_DIR}/Info.plist" "${OUTPUT_APP}/Contents/Info.plist"

# Ensure the app bundle has a coherent code signature bound to Info.plist metadata.
# This stabilizes the app identity used by macOS privacy/TCC checks.
codesign --force --deep --sign - "${OUTPUT_APP}"

echo "Built: ${OUTPUT_APP}"
