#!/usr/bin/env bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# Write stop trigger (WhisperDictation app polls and stops recording, transcribes, pastes)
mkdir -p "$TRIGGER_DIR"
touch "$RECORD_STOP_TRIGGER"
log "Stop trigger: $RECORD_STOP_TRIGGER"
