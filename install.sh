#!/bin/bash
set -e

LOG_FILE="install.log"
exec > >(tee -a "$LOG_FILE") 2>&1

# Load common functions
source ./libs/common.sh

mkdir -p status

for module in $(find modules -maxdepth 1 -type f -name '[0-9][0-9]_*.sh' | sort); do
    log "Executing $(basename "$module")"
    bash "$module"
done
