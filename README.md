# 🛟 Liferaft: Linux Backup & Automation System

> *"When your server goes down with the Titanic, you don't debate Jira tickets or groom backlogs. You deploy the liferaft."*  
> An opinionated, zero-bloat automated daily backup and disaster-recovery pipeline.

---

## The Philosophy (The DHH Way)

Modern sysadmin work is poisoned by overcomplication. People install 500 MB container agents with 40 Python dependencies just to copy three directories onto a disk. 

We reject that noise. 

UNIX gave us `tar`, `gzip`, `find`, and `cron` between 1975 and 1979. They were perfected decades ago. **Liferaft** honors that craftsmanship:
- **Convention over configuration:** Sane defaults in a single, human-readable config.
- **Fail loud, fail early:** Strict Bash (`set -euo pipefail`) with error traps and clear audit logs.
- **No untested hopes:** A backup you haven't restored is a myth. Recovery drills are built right into the workflow.

---

## 📂 Project Architecture

```text
liferaft/
├── config/
│   └── liferaft.conf       # Sane defaults: target paths, retention, vault directory
├── cron/
│   └── liferaft-cron       # The 02:00 AM daily cron watchman
├── lib/
│   ├── archive.sh          # Task 2 & 3: Tar bundling & gzip compression
│   ├── retention.sh        # Task 6: 7-day automated pruning (The Grim Reaper)
│   └── logger.sh           # Task 4: Timestamped ledger & error traps
├── bin/
│   └── liferaft            # The Captain's Bridge: main executable orchestrator
├── restore.sh              # Task 8: Disaster recovery drill & test extraction
├── setup.sh                # Task 1 & 5: One-shot vault creation & cron registration
└── README.md               # The Manifesto & Team Delegation Board
```

---

## 👥 Team Work Breakdown (Assign These to Your Team)

| Teammate | Focus Area | Files to Implement | Core Tasks Covered |
| :--- | :--- | :--- | :--- |
| **Teammate 1** | **The Shipyard (Setup & Permissions)** | `setup.sh`, `cron/liferaft-cron` | **Task 1:** Create `/backup` with `chmod 700`<br>**Task 5:** Install daily `cron` job |
| **Teammate 2** | **The Cargo Master (Tar & Compression)** | `lib/archive.sh`, `config/liferaft.conf` | **Task 2:** Archive `/etc` and `/home`<br>**Task 3:** Dynamic timestamp & gzip compression |
| **Teammate 3** | **The Ledger & Reaper (Logs & Retention)** | `lib/logger.sh`, `lib/retention.sh` | **Task 4:** Logging & error traps<br>**Task 6:** 7-day cleanup via `find -mtime +7` |
| **Teammate 4** | **The Quartermaster (Recovery & Verification)** | `restore.sh`, `bin/liferaft` | **Task 7:** Manual run & audit<br>**Task 8:** Disaster drill extraction into `/tmp` |

*(Each file has explicit `TODO: [Teammate - ...]` markers with sample syntax to guide implementation).*

---

## 🎯 Verification Checklist (Evidence for Evaluator)

| Requirement | Verification Command | Expected Output |
| :--- | :--- | :--- |
| **1. Syntax Check** | `bash -n bin/liferaft && bash -n restore.sh` | Clean exit (no syntax errors). |
| **2. Permissions** | `ls -ld /backup` | `drwx------ root root /backup` (700). |
| **3. Scheduled Cron** | `sudo crontab -l` or `cat /etc/cron.d/liferaft` | Shows `0 2 * * * root /usr/local/bin/liferaft`. |
| **4. Manual Execution** | `sudo ./bin/liferaft` | Creates stamped archive and appends to log. |
| **5. Archive Table of Contents** | `tar -tzf /backup/liferaft-*.tar.gz \| head -n 15` | Lists contents without unpacking. |
| **6. Disaster Recovery Test** | `sudo ./restore.sh /tmp/liferaft_restore_test` | Extracts files into sandbox; proves integrity. |
| **7. Retention Check** | `touch -d "8 days ago" /backup/liferaft-old.tar.gz && sudo ./bin/liferaft` | Old file gets detected and deleted. |
| **8. Audit Trail** | `cat /backup/liferaft.log` | Displays clean `[INFO]`, `[SUCCESS]` timestamps. |
