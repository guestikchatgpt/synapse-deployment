#!/bin/bash
set -e

# Load common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../libs/common.sh"

MODULE_NAME=$(basename "$0")
MODULE_ID="${MODULE_NAME%.sh}"
STATUS_FILE="status/${MODULE_ID}.done"

if [ -f "$STATUS_FILE" ]; then
    log "$MODULE_ID already completed, skipping"
    exit 0
fi

log "Running $MODULE_ID"
# Example module logic: create marker file under temp directory
mkdir -p tmp
# Add a message to show execution
printf '%s\n' "$MODULE_ID executed" >> tmp/executed.txt

mkdir -p status
touch "$STATUS_FILE"
log "$MODULE_ID completed"
