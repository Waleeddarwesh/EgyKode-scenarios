#!/bin/bash
D=/root/dr
cd "$D" 2>/dev/null || { echo "FAIL: no $D"; exit 1; }

[ -x backup.sh ] || { echo "FAIL: no executable backup.sh"; exit 1; }

DUMP=$(ls -t backups/*.dump 2>/dev/null | head -1)
[ -n "$DUMP" ] || { echo "FAIL: no backup file in backups/"; exit 1; }

# The archive has to parse. This is the same question a restore will ask, which
# is why it is worth asking now rather than during the incident.
docker compose exec -T db pg_restore --list "/backups/$(basename "$DUMP")" >/dev/null 2>&1 || {
  echo "FAIL: $DUMP is not a readable archive"; exit 1; }

# And contain something. An empty dump is a perfectly valid archive, and the
# file size will not tell you the difference.
TABLES=$(docker compose exec -T db pg_restore --list "/backups/$(basename "$DUMP")" 2>/dev/null | grep -c "TABLE DATA")
[ "${TABLES:-0}" -ge 2 ] || {
  echo "FAIL: $DUMP contains ${TABLES:-0} tables with data, expected at least 2"; exit 1; }

# The script must verify, not merely dump. A backup script that only checks the
# file exists is the one that reports success for weeks.
grep -q "pg_restore --list" backup.sh || {
  echo "FAIL: backup.sh never reads the archive back - it cannot know whether it produced a backup"
  exit 1; }
grep -qE "rm -f|exit 1" backup.sh || {
  echo "FAIL: backup.sh does not fail on a bad archive"; exit 1; }

# Prove the verification actually rejects something. A check that has never
# said no is a check nobody has tested.
cp "$DUMP" backups/verify-corrupt.dump
dd if=/dev/urandom of=backups/verify-corrupt.dump bs=1 seek=2000 count=400 conv=notrunc 2>/dev/null
if docker compose exec -T db pg_restore --list /backups/verify-corrupt.dump >/dev/null 2>&1; then
  echo "FAIL: a deliberately corrupted archive still parsed - the verification proves nothing"
  rm -f backups/verify-corrupt.dump
  exit 1
fi
rm -f backups/verify-corrupt.dump

echo "PASS - $DUMP verified with $TABLES tables, and corruption is detected"
exit 0
