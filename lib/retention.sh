#!/usr/bin/env bash
# ==============================================================================
# lib/retention.sh — The Grim Reaper
# "Hoarding data until the disk fills up is not a strategy; it's negligence."
# ==============================================================================

set -euo pipefail

# ------------------------------------------------------------------------------
# Function: prune_stale_backups
# Safely purges archives older than RETENTION_DAYS.
# ------------------------------------------------------------------------------
prune_stale_backups() {
    local target_dir="$1"
    local days="$2"
    local pattern="${3:-*.tar.gz}"

    if [[ ! -d "$target_dir" ]]; then
        log_msg "WARN" "Retention check bypassed: directory '$target_dir' does not exist."
        return 0
    fi

    log_msg "INFO" "Auditing archives older than ${days} days in ${target_dir}..."

    # Collect stale files matching pattern and mtime
    local stale_files=()
    while IFS= read -r -d '' file; do
        stale_files+=("$file")
    done < <(find "$target_dir" -maxdepth 1 -type f -name "$pattern" -mtime +"$days" -print0 2>/dev/null)

    local count="${#stale_files[@]}"

    if [[ "$count" -eq 0 ]]; then
        log_msg "INFO" "Retention check clear: No archives older than ${days} days found."
        return 0
    fi

    log_msg "WARN" "Found ${count} stale archive(s) exceeding ${days}-day retention limit. Pruning..."

    for file in "${stale_files[@]}"; do
        local fname
        fname="$(basename "$file")"
        if rm -f "$file"; then
            log_msg "INFO" "Pruned expired archive: ${fname}"
        else
            log_msg "ERROR" "Failed to prune: ${fname}"
        fi
    done

    log_msg "SUCCESS" "Retention enforcement complete. Reclaimed storage capacity."
    return 0
}
