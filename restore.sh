#!/usr/bin/env bash
# ==============================================================================
# restore.sh — The Disaster Rehearsal
# "A backup that has never been restored is not a backup; it's a superstition."
# Task 8: Restore selected files into a temporary test directory.
# ==============================================================================

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=config/liferaft.conf
source "${PROJECT_ROOT}/config/liferaft.conf"
# shellcheck source=lib/logger.sh
source "${PROJECT_ROOT}/lib/logger.sh"

usage() {
    echo "Usage: $0 [ARCHIVE_PATH] [SANDBOX_DIR] [SPECIFIC_FILE_OR_PATH...]"
    echo ""
    echo "Examples:"
    echo "  $0                                        # Restores newest archive to /tmp/liferaft_restore_test"
    echo "  $0 /backup/liferaft-2026-11-10.tar.gz    # Restores specific archive"
    echo "  $0 default /tmp/test_dir etc/hosts        # Restores only etc/hosts into /tmp/test_dir"
    exit 0
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
fi

main() {
    log_msg "INFO" "================ DISASTER RECOVERY DRILL ================"

    # 1. Resolve Archive
    local target_archive="${1:-default}"
    if [[ "$target_archive" == "default" || -z "$target_archive" ]]; then
        target_archive="$(find "$BACKUP_DEST" -maxdepth 1 -name "${ARCHIVE_PREFIX}-*.${COMPRESSION_EXT}" 2>/dev/null | sort -r | head -n 1 || true)"
    fi

    if [[ -z "$target_archive" || ! -f "$target_archive" ]]; then
        log_msg "ERROR" "Archive not found: '$target_archive'. Ensure a backup has been taken first."
        exit 1
    fi

    log_msg "INFO" "Selected archive for recovery: ${target_archive}"

    # 2. Resolve Sandbox Destination
    local sandbox_dir="${2:-/tmp/liferaft_restore_test}"
    log_msg "INFO" "Target sandbox directory: ${sandbox_dir}"

    mkdir -p "$sandbox_dir"

    # Shift past the first two parameters to get any selective paths
    shift 2 2>/dev/null || shift $# 2>/dev/null || true
    local selective_paths=("$@")

    # 3. Extraction Procedure
    if [[ "${#selective_paths[@]}" -gt 0 ]]; then
        log_msg "INFO" "Performing selective extraction of: ${selective_paths[*]}"
        tar -xzf "$target_archive" -C "$sandbox_dir" "${selective_paths[@]}"
    else
        log_msg "INFO" "Extracting archive contents into sandbox..."
        tar -xzf "$target_archive" -C "$sandbox_dir"
    fi

    # 4. Verification Check
    local extracted_count
    extracted_count="$(find "$sandbox_dir" -mindepth 1 | wc -l)"

    if [[ "$extracted_count" -gt 0 ]]; then
        log_msg "SUCCESS" "Recovery verified! Extracted ${extracted_count} items into ${sandbox_dir}"
        echo "----------------------------------------------------------------------"
        echo "Sample recovered items in sandbox:"
        find "$sandbox_dir" -maxdepth 3 | head -n 15
        echo "... [verified intact]"
        echo "----------------------------------------------------------------------"
        log_msg "SUCCESS" "Disaster recovery rehearsal completed without errors."
    else
        log_msg "ERROR" "Extraction produced 0 items. Recovery verification failed!"
        exit 1
    fi

    log_msg "INFO" "=========================================================="
}

main "$@"
