#!/usr/bin/env bash
# ==============================================================================
# setup.sh — The Shipyard Installer
# "One script to set the stage, lock the doors, and set the alarm."
# Task 1: Create /backup with appropriate permissions
# Task 5: Install daily cron job
# ==============================================================================

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=config/liferaft.conf
source "${PROJECT_ROOT}/config/liferaft.conf"

echo "🛠️  Preparing the Liferaft environment..."

# ------------------------------------------------------------------------------
# 1. Check Root Privileges
# ------------------------------------------------------------------------------
if [[ "$EUID" -ne 0 ]]; then
    echo "⚠️  Liferaft system installation requires root privileges to configure /backup and /etc/cron.d/."
    echo "    Please run: sudo ./setup.sh"
    echo ""
    echo "    (Tip: If running in a local unprivileged environment for testing, run:"
    echo "     ./tests/test_liferaft.sh)"
    exit 1
fi

# ------------------------------------------------------------------------------
# 2. Task 1: Create Backup Vault with Strict Permissions
# ------------------------------------------------------------------------------
echo "📁 Setting up vault at $BACKUP_DEST..."
mkdir -p "$BACKUP_DEST"
chown root:root "$BACKUP_DEST"
chmod 700 "$BACKUP_DEST"
echo "   [✓] $BACKUP_DEST secured with permissions 700 (owner root:root)."

# ------------------------------------------------------------------------------
# 3. Task 5: Install Executable & Cron Job
# ------------------------------------------------------------------------------
echo "⏱️  Installing liferaft executable into /usr/local/bin..."
chmod +x "${PROJECT_ROOT}/bin/liferaft"
chmod +x "${PROJECT_ROOT}/restore.sh"
cp "${PROJECT_ROOT}/bin/liferaft" /usr/local/bin/liferaft
chmod 755 /usr/local/bin/liferaft
echo "   [✓] /usr/local/bin/liferaft installed and executable."

echo "🕒 Installing daily cron schedule..."
if [[ -d "/etc/cron.d" ]]; then
    cp "${PROJECT_ROOT}/cron/liferaft-cron" /etc/cron.d/liferaft
    chmod 644 /etc/cron.d/liferaft
    chown root:root /etc/cron.d/liferaft
    echo "   [✓] /etc/cron.d/liferaft installed (02:00 AM daily)."
else
    # Fallback to crontab if /etc/cron.d does not exist
    (crontab -l 2>/dev/null | grep -v 'liferaft' || true; cat "${PROJECT_ROOT}/cron/liferaft-cron") | crontab -
    echo "   [✓] Daily job registered directly in root crontab."
fi

echo ""
echo "✨ Installation complete! You can now execute 'liferaft' from anywhere."
