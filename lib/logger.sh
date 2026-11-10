#!/usr/bin/env bash
# ==============================================================================
# lib/logger.sh — The Ship's Ledger
# "If a server crashes in the datacenter and no log recorded it, did it even happen?"
# ==============================================================================

set -euo pipefail

# ANSI color codes for human-friendly interactive terminal output
if [[ -t 1 ]]; then
    COLOR_RESET="\033[0m"
    COLOR_INFO="\033[36m"     # Cyan
    COLOR_SUCCESS="\033[32m"  # Green
    COLOR_WARN="\033[33m"     # Yellow
    COLOR_FAIL="\033[31m"     # Red
else
    COLOR_RESET=""
    COLOR_INFO=""
    COLOR_SUCCESS=""
    COLOR_WARN=""
    COLOR_FAIL=""
fi

# Track any in-progress archive so we can clean up if an error is trapped
CURRENT_ARCHIVE_IN_PROGRESS=""

# ------------------------------------------------------------------------------
# Function: log_msg
# Writes timestamped entries to stdout AND appends cleanly to the log file.
# ------------------------------------------------------------------------------
log_msg() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"

    local log_entry="[$timestamp] [$level] $message"

    # Terminal output with color
    case "$level" in
        INFO)    echo -e "${COLOR_INFO}${log_entry}${COLOR_RESET}" ;;
        SUCCESS) echo -e "${COLOR_SUCCESS}${log_entry}${COLOR_RESET}" ;;
        WARN)    echo -e "${COLOR_WARN}${log_entry}${COLOR_RESET}" ;;
        ERROR)   echo -e "${COLOR_FAIL}${log_entry}${COLOR_RESET}" >&2 ;;
        *)       echo "$log_entry" ;;
    esac

    # Append to log file on disk if destination directory is ready
    if [[ -n "${LOG_FILE:-}" ]]; then
        local log_dir
        log_dir="$(dirname "$LOG_FILE")"
        if [[ -d "$log_dir" ]] && [[ -w "$log_dir" || -w "$LOG_FILE" ]]; then
            echo "$log_entry" >> "$LOG_FILE"
        fi
    fi
}

# ------------------------------------------------------------------------------
# Function: handle_error
# Trap handler for unexpected pipeline failures (ERR signal).
# ------------------------------------------------------------------------------
handle_error() {
    local exit_code="$?"
    local line_no="$1"
    local command_str="${2:-unknown_command}"

    log_msg "ERROR" "CRITICAL: Command '${command_str}' failed at line ${line_no} with exit code ${exit_code}."

    # Clean up incomplete corrupted archive if tar was interrupted
    if [[ -n "${CURRENT_ARCHIVE_IN_PROGRESS:-}" ]] && [[ -f "$CURRENT_ARCHIVE_IN_PROGRESS" ]]; then
        log_msg "WARN" "Purging incomplete corrupted archive: ${CURRENT_ARCHIVE_IN_PROGRESS}"
        rm -f "$CURRENT_ARCHIVE_IN_PROGRESS"
    fi

    log_msg "ERROR" "Liferaft pipeline aborted abnormally. Check system logs for details."
    exit "$exit_code"
}
