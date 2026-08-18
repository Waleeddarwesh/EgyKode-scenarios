# A backup, and proof that it is one

```
cd ~/dr
docker compose exec -T db pg_dump -U postgres -d platform -Fc -f /backups/platform.dump
ls -lh backups/
```{{exec}}

**`-Fc` is the custom format**, and it is the one to use. It is compressed, it
can be restored selectively, and — the reason it matters here — it carries a
table of contents that can be read back without touching a database.

A plain SQL dump is just text: the only way to find out whether it is valid is
to run it, and by then you are already restoring.

## Read the backup without restoring it

```
cd ~/dr
docker compose exec -T db pg_restore --list /backups/platform.dump | head -12
echo "---"
docker compose exec -T db pg_restore --list /backups/platform.dump | grep -c "TABLE DATA"
```{{exec}}

Two `TABLE DATA` entries and the schema objects around them. **`pg_restore
--list` parses the archive and fails on a damaged one**, which makes it a
verification you can run on every backup, every night, for almost no cost.

That check is the difference between having a backup and having a file.

## Corrupt one on purpose

```
cd ~/dr
cp backups/platform.dump backups/corrupt.dump
dd if=/dev/urandom of=backups/corrupt.dump bs=1 seek=2000 count=400 conv=notrunc 2>/dev/null
ls -l backups/platform.dump backups/corrupt.dump
```{{exec}}

Same size, same name, same place, modified time barely different. Nothing about
the file on disk says anything is wrong — and a backup script that checks only
"did the file get created" reports success.

```
cd ~/dr
echo "--- the good one:"
docker compose exec -T db pg_restore --list /backups/platform.dump > /dev/null 2>&1 && echo "valid" || echo "REJECTED"
echo "--- the corrupted one:"
docker compose exec -T db pg_restore --list /backups/corrupt.dump > /dev/null 2>&1 && echo "valid" || echo "REJECTED"
```{{exec}}

The corrupted archive is rejected. Not by a checksum you maintained — by the
tool that would have to read it, asked the same question it will be asked
during the incident.

## Make the check part of taking the backup

```
cd ~/dr
cat > backup.sh <<'SH'
#!/bin/bash
set -euo pipefail

STAMP=$(date -u +%Y%m%dT%H%M%SZ)
NAME="platform-${STAMP}.dump"

cd "$(dirname "$0")"
# The database writes to /backups inside the container; that same directory is
# ./backups here. Binary through `docker compose exec` gets mangled, so the
# dump is written server-side rather than piped out.
docker compose exec -T db pg_dump -U postgres -d platform -Fc -f "/backups/${NAME}"

# A backup nobody has read is a file. Verify before reporting success, and
# delete anything that does not parse so it can never be restored by mistake.
if ! docker compose exec -T db pg_restore --list "/backups/${NAME}" > /dev/null 2>&1; then
  echo "VERIFY FAILED: ${NAME} is not a readable archive" >&2
  rm -f "backups/${NAME}"
  exit 1
fi

TABLES=$(docker compose exec -T db pg_restore --list "/backups/${NAME}" | grep -c "TABLE DATA")
if [ "$TABLES" -lt 2 ]; then
  echo "VERIFY FAILED: ${NAME} contains $TABLES tables, expected at least 2" >&2
  rm -f "backups/${NAME}"
  exit 1
fi

echo "OK: ${NAME} ($(du -h "backups/${NAME}" | cut -f1), $TABLES tables)"
SH
chmod +x backup.sh
./backup.sh
```{{exec}}

The table count matters as much as the parse. **An empty backup is a valid
archive** — dump the wrong database, or one whose permissions hid every table,
and you get a perfectly readable file containing nothing. Size alone will not
tell you: a compressed empty dump is a few hundred bytes, and so is a small one.

**Done when:** `backup.sh` exists, produces a verified dump, and rejects an
archive that does not parse.
