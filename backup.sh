#!/usr/bin/env bash
# ==============================================================================
# backup.sh — Core Backup Script
# Handles: Archiving, Compression, Logging, and 7-day Retention
# ==============================================================================
set -e

# 1. Load settings from backup.conf
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/backup.conf"

# Allow override for testing without root
BACKUP_DEST="${LIFERAFT_DEST:-$BACKUP_DEST}"
LOG_FILE="${BACKUP_DEST}/backup.log"
if [ -n "${LIFERAFT_SOURCES:-}" ]; then
    read -r -a BACKUP_SOURCES <<< "$LIFERAFT_SOURCES"
fi

# 2. Simple logger function (Task 4)
log() {
    local MSG="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo "$MSG"
    echo "$MSG" >> "$LOG_FILE"
}

# Ensure backup destination folder exists (Task 1)
mkdir -p "$BACKUP_DEST"

# 3. Create unique date-based filename (Task 3)
DATE=$(date +%Y-%m-%d_%H%M%S)
ARCHIVE_NAME="backup-${DATE}.tar.gz"
ARCHIVE_PATH="${BACKUP_DEST}/${ARCHIVE_NAME}"

log "Starting backup for: ${BACKUP_SOURCES[*]}"

# 4. Create compressed archive with tar (Task 2 & 3)
# -c = create, -z = gzip compress, -f = output file
if tar -czf "$ARCHIVE_PATH" "${BACKUP_SOURCES[@]}" 2>> "$LOG_FILE"; then
    log "Backup created successfully: $ARCHIVE_NAME"
else
    log "ERROR: tar backup failed!"
    exit 1
fi

# 5. Remove backups older than 7 days (Task 6)
log "Cleaning up backups older than ${RETENTION_DAYS} days..."
find "$BACKUP_DEST" -type f -name "backup-*.tar.gz" -mtime +"$RETENTION_DAYS" -exec rm -f {} \;

log "Backup completed successfully."
