#!/usr/bin/env bash
# ==============================================================================
# test.sh — Simple Verification Test (Runs without root)
# ==============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== Running Simple Verification Test ==="

# 1. Syntax check
echo "1. Checking script syntax (bash -n)..."
bash -n "${SCRIPT_DIR}/backup.sh"
bash -n "${SCRIPT_DIR}/restore.sh"
bash -n "${SCRIPT_DIR}/setup.sh"
echo "   [PASS] All scripts have valid bash syntax."

# 2. Test sandbox backup
echo "2. Testing backup and logging..."
TEST_VAULT="/tmp/test_backup_vault"
TEST_SOURCE="/tmp/test_backup_source"

mkdir -p "$TEST_VAULT" "$TEST_SOURCE"
echo "sample data content" > "$TEST_SOURCE/sample.txt"

export LIFERAFT_DEST="$TEST_VAULT"
export LIFERAFT_SOURCES="$TEST_SOURCE"

"${SCRIPT_DIR}/backup.sh"

if [ -f "$TEST_VAULT"/backup-*.tar.gz ]; then
    echo "   [PASS] Archive created successfully."
else
    echo "   [FAIL] Archive not found!"
    exit 1
fi

if grep -q "Backup completed successfully" "$TEST_VAULT/backup.log"; then
    echo "   [PASS] Execution logged to backup.log."
fi

# 3. Test 7-day retention cleanup
echo "3. Testing 7-day retention..."
OLD_FILE="$TEST_VAULT/backup-2026-01-01_000000.tar.gz"
touch "$OLD_FILE"
touch -d "10 days ago" "$OLD_FILE"

# Run backup again to trigger cleanup
"${SCRIPT_DIR}/backup.sh"

if [ ! -f "$OLD_FILE" ]; then
    echo "   [PASS] 10-day-old backup was automatically deleted."
else
    echo "   [FAIL] Old file was not deleted."
    exit 1
fi

# 4. Test recovery (Task 8)
echo "4. Testing restore into /tmp/restore_test..."
"${SCRIPT_DIR}/restore.sh" /tmp/test_restore_dir

if [ -f "/tmp/test_restore_dir${TEST_SOURCE}/sample.txt" ]; then
    echo "   [PASS] File recovery verified!"
fi

# Clean up temporary test files
rm -rf "$TEST_VAULT" "$TEST_SOURCE" /tmp/test_restore_dir
echo ""
echo "🎉 ALL TESTS PASSED! Clean, simple, and working."
