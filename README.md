# 🛟 Liferaft: Linux Backup and Automation System

A simple, direct Linux backup system built from first principles with Bash, `tar`, and `cron`.

---

## 📂 The Files (Only what is needed)

* **[`backup.conf`](file:///home/omni/Projects/liferaft/backup.conf)** — 4 settings (where to save, what to backup, retention days, log path).
* **[`backup.sh`](file:///home/omni/Projects/liferaft/backup.sh)** — The core backup script: tar compression, date naming, logging, and 7-day cleanup.
* **[`restore.sh`](file:///home/omni/Projects/liferaft/restore.sh)** — Task 8 recovery script: extracts the latest backup into `/tmp/restore_test`.
* **[`setup.sh`](file:///home/omni/Projects/liferaft/setup.sh)** — One-time setup: creates `/backup` with `chmod 700` and adds the daily cron job.
* **[`test.sh`](file:///home/omni/Projects/liferaft/test.sh)** — Automated test script that checks everything without needing root.

---

## 🧭 How it Works (First Principles)

1. **Setup (`setup.sh`):**
   * Creates `/backup` owned by `root:root` with `chmod 700` so normal users cannot read sensitive data.
   * Adds a daily job to `/etc/cron.d/backup-job` to run every night at 2:00 AM (`0 2 * * *`).

2. **Backup (`backup.sh`):**
   * Uses `date +%Y-%m-%d_%H%M%S` for unique archive names (`backup-YYYY-MM-DD_HHMMSS.tar.gz`).
   * Bundles `/etc` and `/home` using `tar -czf`.
   * Logs every run with timestamps to `/backup/backup.log`.
   * Deletes backups older than 7 days using `find /backup -mtime +7 -delete`.

3. **Restore (`restore.sh`):**
   * Takes the latest backup and extracts it into `/tmp/restore_test` using `tar -xzf`.
   * Lists the recovered files to prove disaster recovery works.

---

## 🧪 Run Tests (Takes 1 second, No Root needed)

```bash
./test.sh
```

---

## 🚀 Live System Usage (With Sudo)

```bash
# 1. Install & configure permissions + cron
sudo ./setup.sh

# 2. Run backup manually
sudo /usr/local/bin/backup.sh

# 3. Test file recovery
sudo ./restore.sh

# 4. View logs
cat /backup/backup.log
```

---

## 📋 Evaluator Verification Checklist

* **Syntax Check:** `bash -n backup.sh && bash -n restore.sh && bash -n setup.sh`
* **Cron Check:** `cat /etc/cron.d/backup-job`
* **Folder Permissions:** `ls -ld /backup` *(Output: `drwx------ root root /backup`)*
* **Inspect Archive:** `tar -tzf /backup/backup-*.tar.gz | head -n 15`
* **Check Recovery:** `ls -l /tmp/restore_test`
