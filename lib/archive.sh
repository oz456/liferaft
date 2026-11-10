#!/usr/bin/env bash
# ==============================================================================
# lib/archive.sh — Packing the Cargo
# "tar was born in 1979. It will outlive Kubernetes, microservices, and all of us."
# ==============================================================================

set -euo pipefail

# ------------------------------------------------------------------------------
# Function: create_archive
# Compresses the requested sources into a single, date-stamped .tar.gz archive.
# ------------------------------------------------------------------------------
create_archive() {
    local target_dest="$1"
    local archive_name="$2"
    shift 2
    local requested_sources=("$@")

    local archive_path="${target_dest}/${archive_name}"

    # 1. Filter and validate existing source directories
    local valid_sources=()
    for src in "${requested_sources[@]}"; do
        if [[ -e "$src" ]]; then
            valid_sources+=("$src")
        else
            log_msg "WARN" "Source path '$src' does not exist; skipping."
        fi
    done

    if [[ "${#valid_sources[@]}" -eq 0 ]]; then
        log_msg "ERROR" "No valid source directories found to backup! Aborting."
        return 1
    fi

    log_msg "INFO" "Bundling sources: ${valid_sources[*]}"
    log_msg "INFO" "Target archive: ${archive_path}"

    # Set tracker for error trap cleanup
    CURRENT_ARCHIVE_IN_PROGRESS="$archive_path"

    # 2. Execute tar with gzip compression
    # --warning=no-file-changed prevents benign exit code 1 if a log file rotated during run
    local tar_opts=("-c" "-z" "-f" "$archive_path")
    if tar --help | grep -q -- '--warning'; then
        tar_opts+=("--warning=no-file-changed")
    fi

    log_msg "INFO" "Executing tar compression pipeline..."
    
    # We capture tar output into the log while monitoring exit status
    local tar_status=0
    tar "${tar_opts[@]}" "${valid_sources[@]}" 2>> "${LOG_FILE:-/dev/null}" || tar_status=$?

    # In GNU tar, exit code 1 means some files were modified while being read (common in live /etc or /var)
    if [[ $tar_status -eq 0 ]] || [[ $tar_status -eq 1 ]]; then
        local archive_size
        archive_size="$(du -sh "$archive_path" 2>/dev/null | awk '{print $1}' || echo "N/A")"
        log_msg "SUCCESS" "Archive successfully created: ${archive_name} (${archive_size})"
        CURRENT_ARCHIVE_IN_PROGRESS=""
        return 0
    else
        log_msg "ERROR" "tar compression failed with exit code ${tar_status}!"
        CURRENT_ARCHIVE_IN_PROGRESS=""
        return "$tar_status"
    fi
}
