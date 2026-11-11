#!/usr/bin/env bash
# ==============================================================================
# setup.sh — System Installer (Task 1 & Task 5)
# Creates /backup with root permissions and registers daily cron job.
# ==============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/backup.conf"

# Must run with sudo
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root: sudo ./setup.sh"
    exit 1
fi

# Task 1: Create /backup and lock permissions to root only (chmod 700)
echo "Creating backup destination at $BACKUP_DEST..."
mkdir -p "$BACKUP_DEST"
chown root:root "$BACKUP_DEST"
chmod 700 "$BACKUP_DEST"
echo "  [✓] $BACKUP_DEST created with chmod 700 (owner: root:root)."

# Task 5: Copy backup script to /usr/local/bin and set daily cron job
echo "Installing backup.sh to /usr/local/bin..."
cp "${SCRIPT_DIR}/backup.sh" /usr/local/bin/backup.sh
cp "${SCRIPT_DIR}/backup.conf" /usr/local/bin/backup.conf
chmod +x /usr/local/bin/backup.sh

echo "Scheduling daily backup at 2:00 AM in cron..."
CRON_JOB="0 2 * * * root /usr/local/bin/backup.sh"

if [ -d "/etc/cron.d" ]; then
    echo "$CRON_JOB" > /etc/cron.d/backup-job
    chmod 644 /etc/cron.d/backup-job
    echo "  [✓] Cron job saved to /etc/cron.d/backup-job"
else
    (crontab -l 2>/dev/null | grep -v 'backup.sh' || true; echo "$CRON_JOB") | crontab -
    echo "  [✓] Cron job added to root crontab."
fi

echo "✨ Setup complete! Run it manually anytime with: sudo /usr/local/bin/backup.sh"
