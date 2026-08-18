#!/bin/bash
# Checks the units as systemd has actually loaded them, not the files on disk.
# A unit with a typo exists as a file and does nothing, which is precisely the
# failure this step is about noticing.
fail() { echo "$1"; exit 1; }

command -v systemctl >/dev/null 2>&1 || fail "systemd is not available in this environment."

systemctl cat db-backup.timer >/dev/null 2>&1 \
  || fail "No db-backup.timer unit. Create it in /etc/systemd/system and run: systemctl daemon-reload"

systemctl is-enabled db-backup.timer >/dev/null 2>&1 \
  || fail "db-backup.timer exists but is not enabled. Run: systemctl enable --now db-backup.timer"

systemctl cat db-backup.timer | grep -q 'Persistent=true' \
  || fail "The timer has no Persistent=true, so a run missed while the machine was off never happens at all."

# The failure path is the point of the step, so it must be wired and proven.
systemctl cat db-backup.service 2>/dev/null | grep -q '^OnFailure=' \
  || fail "db-backup.service has no OnFailure= handler. A failure that only appears in the journal is one nobody sees."

[ -s /var/backups/app/LAST_FAILURE ] \
  || fail "No /var/backups/app/LAST_FAILURE yet. Make the backup fail once and confirm the handler records it."

echo "PASS"
