#!/usr/bin/env bash
# Build WhisperPaste.app from source (no Xcode required, only swiftc)

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="${SCRIPT_DIR}/WhisperPaste"
OUTPUT_APP="${SCRIPT_DIR}/build/WhisperPaste.app"

mkdir -p "${OUTPUT_APP}/Contents/MacOS"
mkdir -p "${OUTPUT_APP}/Contents/Resources"

swiftc -parse-as-library -o "${OUTPUT_APP}/Contents/MacOS/WhisperPaste" \
  -framework AppKit \
  -framework Foundation \
  "${APP_DIR}/AppDelegate.swift"

cp "${APP_DIR}/Info.plist" "${OUTPUT_APP}/Contents/Info.plist"

echo "Built: ${OUTPUT_APP}"
