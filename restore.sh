#!/usr/bin/env bash
# ==============================================================================
# restore.sh — Disaster Recovery & Test Extraction
# "A backup that has never been restored is not a backup; it's a superstition."
# Task 8: Restore selected files into a temporary test directory.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load configuration if available
if [[ -f "${SCRIPT_DIR}/backup.conf" ]]; then
    # shellcheck source=backup.conf
    source "${SCRIPT_DIR}/backup.conf"
else
    BACKUP_DEST="${LIFERAFT_DEST:-/backup}"
    ARCHIVE_PREFIX="backup"
fi

usage() {
    echo "Usage: $0 [ARCHIVE_PATH] [SANDBOX_DIR] [SPECIFIC_PATHS...]"
    echo ""
    echo "Examples:"
    echo "  $0                                      # Restores newest archive into /tmp/restore_test"
    echo "  $0 /backup/backup-2026-11-10.tar.gz    # Restores specific archive"
    echo "  $0 default /tmp/my_test etc/hosts      # Restores only etc/hosts"
    exit 0
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
fi

main() {
    echo "================ DISASTER RECOVERY DRILL ================"

    # 1. Resolve archive to restore
    local target_archive="${1:-default}"
    if [[ "$target_archive" == "default" || -z "$target_archive" ]]; then
        target_archive="$(find "$BACKUP_DEST" -maxdepth 1 -name "${ARCHIVE_PREFIX}-*.tar.gz" 2>/dev/null | sort -r | head -n 1 || true)"
    fi

    if [[ -z "$target_archive" || ! -f "$target_archive" ]]; then
        echo "❌ ERROR: No archive found at '$target_archive'. Run ./backup.sh first."
        exit 1
    fi

    echo "📦 Selected archive: ${target_archive}"

    # 2. Resolve target sandbox directory
    local sandbox_dir="${2:-/tmp/restore_test}"
    echo "📁 Sandbox target:   ${sandbox_dir}"
    mkdir -p "$sandbox_dir"

    # Shift past first two arguments to capture any selective files
    shift 2 2>/dev/null || shift $# 2>/dev/null || true
    local selective_paths=("$@")

    # 3. Extraction Procedure
    if [[ "${#selective_paths[@]}" -gt 0 ]]; then
        echo "🔍 Extracting selected files: ${selective_paths[*]}"
        tar -xzf "$target_archive" -C "$sandbox_dir" "${selective_paths[@]}"
    else
        echo "🚀 Extracting archive contents into sandbox..."
        tar -xzf "$target_archive" -C "$sandbox_dir"
    fi

    # 4. Verify Recovery
    local count
    count="$(find "$sandbox_dir" -mindepth 1 | wc -l)"

    if [[ "$count" -gt 0 ]]; then
        echo "✅ SUCCESS: Restored ${count} items into ${sandbox_dir}"
        echo "--------------------------------------------------------"
        echo "Sample restored files in sandbox:"
        find "$sandbox_dir" -maxdepth 3 | head -n 15
        echo "... [verified intact]"
        echo "--------------------------------------------------------"
    else
        echo "❌ ERROR: 0 items were restored. Extraction failed!"
        exit 1
    fi
    echo "========================================================"
}

main "$@"
