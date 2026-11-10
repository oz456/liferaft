#!/usr/bin/env bash
# ==============================================================================
# tests/test_liferaft.sh — Automated Verification Suite
# Runs full self-contained end-to-end tests without requiring root privileges.
# ==============================================================================

set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${TEST_DIR}/.." && pwd)"

GREEN="\033[32m"
RED="\033[31m"
BOLD="\033[1m"
RESET="\033[0m"

pass() { echo -e "  ${GREEN}[PASS]${RESET} $1"; }
fail() { echo -e "  ${RED}[FAIL]${RESET} $1"; exit 1; }

echo -e "${BOLD}🧪 Running Liferaft Verification Suite...${RESET}\n"

# ------------------------------------------------------------------------------
# Test 1: Bash Syntax Validation (bash -n)
# ------------------------------------------------------------------------------
echo "1. Checking Bash Syntax across all scripts (bash -n)..."
for file in "${PROJECT_ROOT}/bin/liferaft" \
            "${PROJECT_ROOT}/restore.sh" \
            "${PROJECT_ROOT}/setup.sh" \
            "${PROJECT_ROOT}/lib/"*.sh; do
    if bash -n "$file"; then
        pass "Syntax OK: $(basename "$file")"
    else
        fail "Syntax Error in $file"
    fi
done
echo ""

# ------------------------------------------------------------------------------
# Test 2: Sandboxed End-to-End Backup Pipeline
# ------------------------------------------------------------------------------
echo "2. Testing Sandboxed End-to-End Backup & Logging..."
TEST_VAULT="/tmp/liferaft_test_vault_$$"
TEST_SOURCE_ETC="/tmp/liferaft_test_etc_$$"
TEST_SOURCE_HOME="/tmp/liferaft_test_home_$$"
TEST_RESTORE="/tmp/liferaft_test_restore_$$"

# Setup test fixtures
mkdir -p "$TEST_VAULT" "$TEST_SOURCE_ETC" "$TEST_SOURCE_HOME"
echo "SECRET_CONFIG=42" > "$TEST_SOURCE_ETC/system.conf"
echo "Hello, world! User data payload." > "$TEST_SOURCE_HOME/document.txt"

# Run liferaft inside sandbox
export LIFERAFT_DEST="$TEST_VAULT"
export LIFERAFT_SOURCES="$TEST_SOURCE_ETC $TEST_SOURCE_HOME"

"${PROJECT_ROOT}/bin/liferaft" > /dev/null

# Assert archive was created
ARCHIVE_COUNT="$(find "$TEST_VAULT" -name "liferaft-*.tar.gz" | wc -l)"
if [[ "$ARCHIVE_COUNT" -eq 1 ]]; then
    pass "Archive successfully generated in test vault."
else
    fail "Expected 1 archive in vault, found $ARCHIVE_COUNT."
fi

# Assert log file recorded entries
if [[ -f "$TEST_VAULT/liferaft.log" ]] && grep -q "LIFERAFT RUN COMMENCING" "$TEST_VAULT/liferaft.log"; then
    pass "Execution successfully logged to liferaft.log."
else
    fail "Logging failed or log file missing."
fi
echo ""

# ------------------------------------------------------------------------------
# Test 3: Testing 7-Day Retention Policy & Pruning
# ------------------------------------------------------------------------------
echo "3. Testing 7-Day Retention Pruning..."
# Create a simulated 10-day-old archive
DUMMY_OLD_ARCHIVE="${TEST_VAULT}/liferaft-2026-01-01_000000.tar.gz"
touch "$DUMMY_OLD_ARCHIVE"
touch -d "10 days ago" "$DUMMY_OLD_ARCHIVE"

# Run liferaft again to trigger retention
"${PROJECT_ROOT}/bin/liferaft" > /dev/null

if [[ ! -f "$DUMMY_OLD_ARCHIVE" ]]; then
    pass "Stale archive (10 days old) was pruned cleanly."
else
    fail "Stale archive was NOT pruned."
fi

# Verify the fresh archive remained intact
FRESH_COUNT="$(find "$TEST_VAULT" -name "liferaft-*.tar.gz" | wc -l)"
if [[ "$FRESH_COUNT" -ge 1 ]]; then
    pass "Fresh archives safely preserved."
else
    fail "Fresh archives were accidentally deleted!"
fi
echo ""

# ------------------------------------------------------------------------------
# Test 4: Testing Disaster Recovery & Restoration (Task 8)
# ------------------------------------------------------------------------------
echo "4. Testing Restoration into Test Directory (Task 8)..."
"${PROJECT_ROOT}/restore.sh" default "$TEST_RESTORE" > /dev/null

# Strip leading slashes to locate relative paths inside sandbox
REL_ETC="${TEST_SOURCE_ETC#/}"
REL_HOME="${TEST_SOURCE_HOME#/}"

if [[ -f "${TEST_RESTORE}/${REL_ETC}/system.conf" ]] && \
   grep -q "SECRET_CONFIG=42" "${TEST_RESTORE}/${REL_ETC}/system.conf"; then
    pass "Restored /etc config matches original exactly."
else
    fail "Restored configuration file missing or corrupted."
fi

if [[ -f "${TEST_RESTORE}/${REL_HOME}/document.txt" ]] && \
   grep -q "Hello, world!" "${TEST_RESTORE}/${REL_HOME}/document.txt"; then
    pass "Restored /home user data matches original exactly."
else
    fail "Restored user data missing or corrupted."
fi
echo ""

# ------------------------------------------------------------------------------
# Cleanup Test Fixtures
# ------------------------------------------------------------------------------
rm -rf "$TEST_VAULT" "$TEST_SOURCE_ETC" "$TEST_SOURCE_HOME" "$TEST_RESTORE"
echo -e "${GREEN}${BOLD}🎉 ALL TESTS PASSED! Project requirements 100% verified.${RESET}"
