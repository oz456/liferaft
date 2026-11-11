#!/usr/bin/env bash
# ==============================================================================
# backup.sh — Automated Linux Backup, Compression, Logging & Retention
# "No bloat, no 40-layer abstractions. Just pure UNIX reliability."
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ------------------------------------------------------------------------------
# Load Configuration (fallback to defaults if config is missing)
# ------------------------------------------------------------------------------
if [[ -f "${SCRIPT_DIR}/backup.conf" ]]; then
    # shellcheck source=backup.conf
    source "${SCRIPT_DIR}/backup.conf"
else
    BACKUP_DEST="${LIFERAFT_DEST:-/backup}"
    BACKUP_SOURCES=("/etc" "/home")
    RETENTION_DAYS="${LIFERAFT_RETENTION_DAYS:-7}"
    LOG_FILE="${BACKUP_DEST}/backup.log"
    ARCHIVE_PREFIX="backup"
fi

# Track in-progress archive for cleanup on unexpected error
CURRENT_ARCHIVE=""

# Terminal color output (disabled automatically if piping)
if [[ -t 1 ]]; then
    C_RESET="\033[0m"
    C_INFO="\033[36m"
    C_SUCCESS="\033[32m"
    C_WARN="\033[33m"
    C_FAIL="\033[31m"
else
    C_RESET="" C_INFO="" C_SUCCESS="" C_WARN="" C_FAIL=""
fi

# ------------------------------------------------------------------------------
# Task 4: Logging & Error Handling
# ------------------------------------------------------------------------------
log() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    local entry="[$timestamp] [$level] $message"

    # Terminal output
    case "$level" in
        INFO)    echo -e "${C_INFO}${entry}${C_RESET}" ;;
        SUCCESS) echo -e "${C_SUCCESS}${entry}${C_RESET}" ;;
        WARN)    echo -e "${C_WARN}${entry}${C_RESET}" ;;
        ERROR)   echo -e "${C_FAIL}${entry}${C_RESET}" >&2 ;;
        *)       echo "$entry" ;;
    esac

    # File output (if parent directory exists and is writable)
    local log_dir
    log_dir="$(dirname "$LOG_FILE")"
    if [[ -d "$log_dir" ]] && [[ -w "$log_dir" || -w "$LOG_FILE" ]]; then
        echo "$entry" >> "$LOG_FILE"
    fi
}

handle_error() {
    local exit_code="$?"
    local line_no="$1"
    log "ERROR" "Pipeline failed at line ${line_no} with exit status ${exit_code}."
    
    # Clean up incomplete corrupt archive if tar was interrupted
    if [[ -n "${CURRENT_ARCHIVE:-}" ]] && [[ -f "$CURRENT_ARCHIVE" ]]; then
        log "WARN" "Purging incomplete corrupt archive: ${CURRENT_ARCHIVE}"
        rm -f "$CURRENT_ARCHIVE"
    fi
    exit "$exit_code"
}

trap 'handle_error $LINENO' ERR

# ------------------------------------------------------------------------------
# Task 2 & 3: Tar Archiving with Compression & Date Naming
# ------------------------------------------------------------------------------
run_backup() {
    log "INFO" "================ BACKUP PIPELINE COMMENCING ================"

    # Ensure destination vault exists
    if [[ ! -d "$BACKUP_DEST" ]]; then
        log "WARN" "Destination $BACKUP_DEST missing. Attempting directory creation..."
        mkdir -p "$BACKUP_DEST"
    fi

    # Filter for existing source directories
    local valid_sources=()
    for src in "${BACKUP_SOURCES[@]}"; do
        if [[ -e "$src" ]]; then
            valid_sources+=("$src")
        else
            log "WARN" "Source path '$src' does not exist; skipping."
        fi
    done

    if [[ "${#valid_sources[@]}" -eq 0 ]]; then
        log "ERROR" "No valid source directories found to backup. Aborting."
        exit 1
    fi

    # Generate dynamic timestamped archive name (Task 3)
    local timestamp
    timestamp="$(date +%Y-%m-%d_%H%M%S)"
    local archive_name="${ARCHIVE_PREFIX}-${timestamp}.tar.gz"
    local archive_path="${BACKUP_DEST}/${archive_name}"

    log "INFO" "Archiving targets: ${valid_sources[*]}"
    log "INFO" "Creating compressed archive: ${archive_path}"

    CURRENT_ARCHIVE="$archive_path"

    # Tar command with gzip compression (-c: create, -z: gzip, -f: file)
    local tar_opts=("-c" "-z" "-f" "$archive_path")
    if tar --help | grep -q -- '--warning'; then
        tar_opts+=("--warning=no-file-changed")
    fi

    local tar_status=0
    tar "${tar_opts[@]}" "${valid_sources[@]}" 2>> "${LOG_FILE:-/dev/null}" || tar_status=$?

    # In GNU tar, exit code 1 means some files were modified during read (common on live /etc)
    if [[ $tar_status -eq 0 ]] || [[ $tar_status -eq 1 ]]; then
        local archive_size
        archive_size="$(du -sh "$archive_path" 2>/dev/null | awk '{print $1}' || echo "N/A")"
        log "SUCCESS" "Archive successfully created: ${archive_name} (${archive_size})"
        CURRENT_ARCHIVE=""
    else
        log "ERROR" "Tar compression failed with exit code ${tar_status}!"
        CURRENT_ARCHIVE=""
        exit "$tar_status"
    fi

    # --------------------------------------------------------------------------
    # Task 6: 7-Day Retention Policy
    # --------------------------------------------------------------------------
    run_retention

    log "SUCCESS" "Backup pipeline completed successfully."
    log "INFO" "============================================================"
}

run_retention() {
    log "INFO" "Auditing archives older than ${RETENTION_DAYS} days in ${BACKUP_DEST}..."

    local stale_files=()
    while IFS= read -r -d '' file; do
        stale_files+=("$file")
    done < <(find "$BACKUP_DEST" -maxdepth 1 -type f -name "${ARCHIVE_PREFIX}-*.tar.gz" -mtime +"$RETENTION_DAYS" -print0 2>/dev/null)

    local count="${#stale_files[@]}"

    if [[ "$count" -eq 0 ]]; then
        log "INFO" "Retention check clear: No archives older than ${RETENTION_DAYS} days found."
        return 0
    fi

    log "WARN" "Found ${count} archive(s) exceeding ${RETENTION_DAYS}-day retention limit. Pruning..."
    for file in "${stale_files[@]}"; do
        local fname
        fname="$(basename "$file")"
        if rm -f "$file"; then
            log "INFO" "Pruned expired archive: ${fname}"
        else
            log "ERROR" "Failed to prune: ${fname}"
        fi
    done
    log "SUCCESS" "Retention enforcement complete. Reclaimed storage."
}

# ------------------------------------------------------------------------------
# CLI Helper Flags (-l, -t, -h)
# ------------------------------------------------------------------------------
list_archives() {
    echo "Archives in ${BACKUP_DEST}:"
    if [[ ! -d "$BACKUP_DEST" ]]; then
        echo "  [Vault directory does not exist yet]"
        return 0
    fi
    ls -lh "$BACKUP_DEST"/*.tar.gz 2>/dev/null || echo "  [No archives present]"
}

inspect_toc() {
    local newest
    newest="$(find "$BACKUP_DEST" -maxdepth 1 -name "${ARCHIVE_PREFIX}-*.tar.gz" 2>/dev/null | sort -r | head -n 1 || true)"
    if [[ -z "$newest" || ! -f "$newest" ]]; then
        echo "No archive found in ${BACKUP_DEST} to inspect."
        exit 1
    fi
    echo "Inspecting Table of Contents (tar -tzf) for: $(basename "$newest")"
    echo "----------------------------------------------------------------------"
    tar -tzf "$newest" | head -n 25
    echo "... [truncated for preview]"
    echo "----------------------------------------------------------------------"
}

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -r, --run       Execute full backup and 7-day retention (default)"
    echo "  -l, --list      List all archives in vault"
    echo "  -t, --toc       Inspect Table of Contents of newest archive (tar -tzf)"
    echo "  -h, --help      Show this help menu"
    exit 0
}

# Main flag router
case "${1:-run}" in
    -r|--run|run) run_backup ;;
    -l|--list)    list_archives ;;
    -t|--toc)     inspect_toc ;;
    -h|--help)    usage ;;
    *)            echo "Unknown option: $1"; usage ;;
esac
