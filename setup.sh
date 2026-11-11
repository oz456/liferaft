#!/usr/bin/env bash
# ==============================================================================
# setup.sh — One-Shot Environment & Cron Installer
# Task 1: Create /backup destination with strict permissions
# Task 5: Schedule daily cron job
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load configuration if available
if [[ -f "${SCRIPT_DIR}/backup.conf" ]]; then
    # shellcheck source=backup.conf
    source "${SCRIPT_DIR}/backup.conf"
else
    BACKUP_DEST="/backup"
fi

echo "🛠️  Setting up the Backup & Automation System..."

# Check root privileges
if [[ "$EUID" -ne 0 ]]; then
    echo "⚠️  Setup requires root permissions to configure /backup and /etc/cron.d/."
    echo "    Please run: sudo ./setup.sh"
    echo ""
    echo "    (Tip: To run automated verification without root, use: ./test.sh)"
    exit 1
fi

# ------------------------------------------------------------------------------
# Task 1: Create /backup with strict permissions (chmod 700, root:root)
# ------------------------------------------------------------------------------
echo "📁 Configuring secure repository at ${BACKUP_DEST}..."
mkdir -p "$BACKUP_DEST"
chown root:root "$BACKUP_DEST"
chmod 700 "$BACKUP_DEST"
echo "   [✓] ${BACKUP_DEST} secured (permissions: 700, owner: root:root)"

# ------------------------------------------------------------------------------
# Task 5: Install executable and daily cron schedule
# ------------------------------------------------------------------------------
echo "⏱️  Installing executable to /usr/local/bin/backup-system..."
chmod +x "${SCRIPT_DIR}/backup.sh"
chmod +x "${SCRIPT_DIR}/restore.sh"
cp "${SCRIPT_DIR}/backup.sh" /usr/local/bin/backup-system
chmod 755 /usr/local/bin/backup-system
echo "   [✓] /usr/local/bin/backup-system installed."

echo "🕒 Registering daily cron job (02:00 AM)..."
CRON_JOB="0 2 * * * root /usr/local/bin/backup-system >> ${BACKUP_DEST}/backup.log 2>&1"

if [[ -d "/etc/cron.d" ]]; then
    echo "$CRON_JOB" > /etc/cron.d/backup-system
    chmod 644 /etc/cron.d/backup-system
    chown root:root /etc/cron.d/backup-system
    echo "   [✓] /etc/cron.d/backup-system created."
else
    (crontab -l 2>/dev/null | grep -v 'backup-system' || true; echo "$CRON_JOB") | crontab -
    echo "   [✓] Schedule registered in root crontab."
fi

echo ""
echo "✨ Setup complete! You can now run 'sudo backup-system' from any terminal."
