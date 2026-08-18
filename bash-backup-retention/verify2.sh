#!/bin/bash
# Idempotence and retention, both proved by running the script in a sandbox
# rather than by trusting what /var/backups/app happens to contain.
fail() { echo "$1"; exit 1; }
S=/root/bin/backup.sh
[ -x "$S" ] || fail "No executable script at $S yet."

sandbox=$(mktemp -d)
cleanup() { rm -rf "$sandbox"; }

# A file older than any sane retention window, and one from today.
touch -d '30 days ago' "$sandbox/db-ancient.tar.gz"
printf 'x' > "$sandbox/db-ancient.tar.gz"
touch -d '30 days ago' "$sandbox/db-ancient.tar.gz"

BACKUP_DIR="$sandbox" SRC=/srv/data "$S" >/dev/null 2>&1 || { cleanup; fail "The script failed when run against a clean directory."; }
first=$(find "$sandbox" -maxdepth 1 -type f -name 'db-*' ! -name '*.partial' | wc -l)

sleep 1
BACKUP_DIR="$sandbox" SRC=/srv/data "$S" >/dev/null 2>&1 || { cleanup; fail "The second run failed. A scheduled job must be safe to run twice."; }
second=$(find "$sandbox" -maxdepth 1 -type f -name 'db-*' ! -name '*.partial' | wc -l)

[ "$second" -gt "$first" ] || { cleanup; fail "The second run produced no new archive — it overwrote or skipped. Timestamp each backup."; }

# Nothing partial may survive a successful run.
partial=$(find "$sandbox" -maxdepth 1 -name '*.partial' | wc -l)
[ "$partial" -eq 0 ] || { cleanup; fail "A .partial file was left behind. Rename it only after the size check passes."; }

# And the ancient file must be gone.
if [ -e "$sandbox/db-ancient.tar.gz" ]; then
  cleanup
  fail "A 30-day-old backup survived. Add a retention step: find \"\$BACKUP_DIR\" -type f -name 'db-*' -mtime +7 -delete"
fi

cleanup
echo "PASS"
