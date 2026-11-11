#!/usr/bin/env bash
# ==============================================================================
# test.sh — End-to-End Automated Verification Test
# Runs all checks in a sandbox without needing root privileges.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

GREEN="\033[32m"
RED="\033[31m"
BOLD="\033[1m"
RESET="\033[0m"

pass() { echo -e "  ${GREEN}[PASS]${RESET} $1"; }
fail() { echo -e "  ${RED}[FAIL]${RESET} $1"; exit 1; }

echo -e "${BOLD}🧪 Running Liferaft Verification Suite...${RESET}\n"

# 1. Syntax Check (bash -n)
echo "1. Checking Bash Syntax across all scripts (bash -n)..."
for file in "${SCRIPT_DIR}/backup.sh" "${SCRIPT_DIR}/restore.sh" "${SCRIPT_DIR}/setup.sh" "${SCRIPT_DIR}/test.sh"; do
    if bash -n "$file"; then
        pass "Syntax OK: $(basename "$file")"
    else
        fail "Syntax Error in $(basename "$file")"
    fi
done
echo ""

# 2. Sandboxed Backup Run
echo "2. Testing Sandboxed Backup & Logging..."
TEST_VAULT="/tmp/liferaft_vault_$$"
TEST_SRC_ETC="/tmp/liferaft_etc_$$"
TEST_SRC_HOME="/tmp/liferaft_home_$$"
TEST_RESTORE="/tmp/liferaft_restore_$$"

mkdir -p "$TEST_VAULT" "$TEST_SRC_ETC" "$TEST_SRC_HOME"
echo "DATABASE_PORT=5432" > "$TEST_SRC_ETC/app.conf"
echo "Project report draft notes." > "$TEST_SRC_HOME/notes.txt"

export LIFERAFT_DEST="$TEST_VAULT"
export LIFERAFT_SOURCES="$TEST_SRC_ETC $TEST_SRC_HOME"

"${SCRIPT_DIR}/backup.sh" > /dev/null

ARCHIVE_COUNT="$(find "$TEST_VAULT" -name "backup-*.tar.gz" | wc -l)"
if [[ "$ARCHIVE_COUNT" -eq 1 ]]; then
    pass "Archive successfully created in sandbox."
else
    fail "Expected 1 archive, found $ARCHIVE_COUNT."
fi

if [[ -f "$TEST_VAULT/backup.log" ]] && grep -q "BACKUP PIPELINE COMMENCING" "$TEST_VAULT/backup.log"; then
    pass "Execution logged to backup.log."
else
    fail "Logging failed."
fi
echo ""

# 3. Retention Test (7-day rule)
echo "3. Testing 7-Day Retention Cleanup..."
OLD_DUMMY="${TEST_VAULT}/backup-2026-01-01_000000.tar.gz"
touch "$OLD_DUMMY"
touch -d "10 days ago" "$OLD_DUMMY"

"${SCRIPT_DIR}/backup.sh" > /dev/null

if [[ ! -f "$OLD_DUMMY" ]]; then
    pass "Old archive (10 days old) was pruned cleanly."
else
    fail "Stale archive was NOT pruned."
fi

if [[ "$(find "$TEST_VAULT" -name "backup-*.tar.gz" | wc -l)" -ge 1 ]]; then
    pass "Fresh archive preserved safely."
else
    fail "Fresh archive was deleted."
fi
echo ""

# 4. Disaster Recovery Restoration Test (Task 8)
echo "4. Testing Restoration into Sandbox (Task 8)..."
"${SCRIPT_DIR}/restore.sh" default "$TEST_RESTORE" > /dev/null

REL_ETC="${TEST_SRC_ETC#/}"
REL_HOME="${TEST_SRC_HOME#/}"

if [[ -f "${TEST_RESTORE}/${REL_ETC}/app.conf" ]] && grep -q "DATABASE_PORT=5432" "${TEST_RESTORE}/${REL_ETC}/app.conf"; then
    pass "Restored /etc config matches original file."
else
    fail "Restored /etc file corrupted or missing."
fi

if [[ -f "${TEST_RESTORE}/${REL_HOME}/notes.txt" ]] && grep -q "Project report" "${TEST_RESTORE}/${REL_HOME}/notes.txt"; then
    pass "Restored /home user data matches original file."
else
    fail "Restored /home file corrupted or missing."
fi
echo ""

# Cleanup fixtures
rm -rf "$TEST_VAULT" "$TEST_SRC_ETC" "$TEST_SRC_HOME" "$TEST_RESTORE"
echo -e "${GREEN}${BOLD}🎉 ALL TESTS PASSED! Everything verified.${RESET}"
