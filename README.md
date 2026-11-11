# 🛟 Liferaft: Linux Backup and Automation System

> *"No bloat, no 40-layer abstractions. Just pure UNIX reliability."*  
> An automated daily backup, logging, 7-day retention, and disaster-recovery pipeline.

---

## 📂 File Structure (Flat & Zero Overhead)

```text
liferaft/
├── backup.conf    # Configuration: sources, destination (/backup), retention (7 days)
├── backup.sh      # Core engine: tar archiving, gzip, logging & 7-day retention
├── restore.sh     # Disaster recovery: Task 8 test extraction into /tmp
├── setup.sh       # System installer: Task 1 (/backup + chmod 700) & Task 5 (cron)
├── test.sh        # Self-contained automated test suite (runs without root)
├── agy.conf       # Antigravity session resumption script
└── README.md      # This guide and verification checklist
```

---

## 🗺️ How the Files Map to Your 8 Tasks

| Task | Requirement | Solved In | Details |
| :---: | :--- | :--- | :--- |
| **1** | Backup destination with permissions | [`setup.sh`](file:///home/omni/Projects/liferaft/setup.sh) | Creates `/backup` with `chmod 700` (owned by `root:root`). |
| **2** | Archive selected dirs (`/etc`, `/home`) | [`backup.sh`](file:///home/omni/Projects/liferaft/backup.sh) | Bundles configured targets into an archive. |
| **3** | Tar with date naming & compression | [`backup.sh`](file:///home/omni/Projects/liferaft/backup.sh) | Generates `backup-YYYY-MM-DD_HHMMSS.tar.gz` using `tar -czf`. |
| **4** | Logging and basic error handling | [`backup.sh`](file:///home/omni/Projects/liferaft/backup.sh) | Records timestamps to `/backup/backup.log` & traps errors. |
| **5** | Schedule script to run daily via cron | [`setup.sh`](file:///home/omni/Projects/liferaft/setup.sh) | Installs `0 2 * * * root /usr/local/bin/backup-system` in `/etc/cron.d/`. |
| **6** | 7-day retention cleanup | [`backup.sh`](file:///home/omni/Projects/liferaft/backup.sh) | Automatically prunes archives older than 7 days via `find -mtime +7`. |
| **7** | Manual run & inspect archive/log | [`backup.sh`](file:///home/omni/Projects/liferaft/backup.sh) | Supports `./backup.sh`, `./backup.sh --list`, `./backup.sh --toc`. |
| **8** | Restore files into test directory | [`restore.sh`](file:///home/omni/Projects/liferaft/restore.sh) | Extracts files into `/tmp/restore_test` and confirms integrity. |

---

## 🧪 Quick Test (No Root Required)

You can run the entire test suite in 1 second:
```bash
./test.sh
```

---

## 🚀 Live System Deployment (For Grading & Production)

### 1. Run Setup (Creates `/backup` with `chmod 700` and configures `cron`)
```bash
sudo ./setup.sh
```

### 2. Run Backup Manually
```bash
sudo backup-system
# Or from this directory:
sudo ./backup.sh
```

### 3. Inspect Table of Contents (`tar -tzf`)
```bash
sudo ./backup.sh --toc
```

### 4. Inspect Execution Log
```bash
cat /backup/backup.log
```

### 5. Prove Disaster Recovery (Task 8 Test Extraction)
```bash
sudo ./restore.sh
# Check restored files:
ls -la /tmp/restore_test
```

---

## 📋 Evaluator Verification Checklist

* **Syntax Check:** `bash -n backup.sh && bash -n restore.sh && bash -n setup.sh`
* **Cron Schedule:** `cat /etc/cron.d/backup-system` or `sudo crontab -l`
* **Secure Vault:** `ls -ld /backup` *(Output: `drwx------ root root /backup`)*
* **Retention Verification:** Run `./test.sh` to see simulated 10-day-old files pruned automatically.
