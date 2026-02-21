#!/usr/bin/env bash
# ==============================================================================
# Script Name: Find Large Folders
# ==============================================================================
#
# Description:
#   This script will display the top 30 folders sorted by size
#
# Metadata:
#   - NinjaOne Script ID: 101
#   - Language: sh
#   - OS Type: Linux
#   - Architecture: 64, 32
#   - Created By: Roland Penner
#   - Created On: 2025-06-12
#   - Last Updated By: Roland Penner
#   - Last Updated: 2025-06-12 13:50:06
#   - Active: True
# ==============================================================================

# This script is used to find large folders in the specified directory.
# Usage: ./find_large_folders.sh /path/to/directory

if [ -z "$1" ]; then
    DIRECTORY="/"
else
    DIRECTORY="$1"

    if [ ! -d "$DIRECTORY" ]; then
        echo "Error: $DIRECTORY is not a valid directory."
        exit 1
    fi
fi

du -haxt 1G "$DIRECTORY" | sort -hr | head -30
