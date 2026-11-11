#!/usr/bin/env bash
# ==============================================================================
# restore.sh — Recovery & Extraction (Task 8)
# Restores files into a test folder to verify the backup actually works.
# ==============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/backup.conf"

BACKUP_DEST="${LIFERAFT_DEST:-$BACKUP_DEST}"
RESTORE_DIR="${1:-/tmp/restore_test}"

# 1. Find the newest backup in the vault
LATEST_BACKUP=$(ls -t "${BACKUP_DEST}"/backup-*.tar.gz 2>/dev/null | head -n 1)

if [ -z "$LATEST_BACKUP" ]; then
    echo "ERROR: No backup found in $BACKUP_DEST"
    exit 1
fi

echo "Found newest backup: $LATEST_BACKUP"
echo "Restoring into test directory: $RESTORE_DIR"

# 2. Create clean destination directory
mkdir -p "$RESTORE_DIR"

# 3. Extract the archive
# -x = extract, -z = gzip, -f = file, -C = target directory
tar -xzf "$LATEST_BACKUP" -C "$RESTORE_DIR"

echo "✅ Restoration completed!"
echo "Files restored inside $RESTORE_DIR:"
ls -l "$RESTORE_DIR"
