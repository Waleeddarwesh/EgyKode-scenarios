# The runbook that made it repeatable

You have just restored a database. The person who does it next will be doing it
at three in the morning, under pressure, possibly without you — and what they
need is not your memory.

```
cd ~/dr
cat > RUNBOOK.md <<'MD'
# Runbook: restore the platform database

**Measured RTO:** see `rto_seconds` (measured on a drill, not estimated)
**RPO:** up to 24 hours — backups run nightly at 02:00

## Before you start

- [ ] Confirm the database is genuinely unrecoverable rather than merely
      unreachable. A restore over a working database loses data
- [ ] Announce the outage. A restore is not reversible once it begins
- [ ] Pick the backup: `ls -t backups/platform-*.dump | head -5`

## Restore

```sh
cd ~/dr

# 1. Verify the archive BEFORE destroying anything.
LATEST=$(ls -t backups/platform-*.dump | head -1)
docker compose exec -T db pg_restore --list "/backups/$(basename $LATEST)" > /dev/null \
  || { echo "archive is unreadable - pick another"; exit 1; }

# 2. Bring up a clean database.
docker compose down -v
docker compose up -d
for i in $(seq 1 40); do
  docker compose exec -T db pg_isready -U postgres -d platform >/dev/null 2>&1 && break
  sleep 2
done

# 3. Restore.
docker compose exec -T db pg_restore -U postgres -d platform --no-owner \
  "/backups/$(basename $LATEST)"

# 4. Verify against known-good numbers before declaring recovery.
docker compose exec -T db psql -U postgres -d platform -tAc "SELECT count(*) FROM customers;"
docker compose exec -T db psql -U postgres -d platform -tAc "SELECT count(*) FROM orders;"
docker compose exec -T db psql -U postgres -d platform -tAc "SELECT sum(total)::numeric(12,2) FROM orders;"
```

## Expected after a good restore

- customers: 500
- orders: 2000
- referential integrity: no order without a customer

## If the restore fails

- **"did not find magic string"** — the archive is corrupt. Use the previous one
- **relation already exists** — restoring over a populated database. Go back to
  step 2 and start from a clean one
- **permission denied on owner** — restore with `--no-owner`, already in step 3
MD
wc -l RUNBOOK.md
```{{exec}}

## What makes this a runbook rather than notes

**Step 1 verifies the archive before step 2 destroys the database.** That
ordering is the whole document. Reverse it and a corrupt backup turns a
recoverable outage into data loss — and reversing it is the natural thing to do
under pressure, because destroying the broken database feels like progress.

**The expected numbers are written down.** "It restored" is not a finding; "500
customers, 2000 orders, total 942269.64" is. Without a known-good figure there
is no way to distinguish a complete restore from a partial one that finished
without error.

**The failure modes are the ones actually seen**, with the fix beside each.

Now prove the document works by following it, rather than by reading it:

```
cd ~/dr
docker compose exec -T db psql -U postgres -d platform -tAc "SELECT count(*) FROM orders;"
LATEST=$(ls -t backups/platform-*.dump | head -1)
docker compose exec -T db pg_restore --list "/backups/$(basename $LATEST)" > /dev/null && echo "archive verified"
docker compose down -v > /dev/null
docker compose up -d > /dev/null
for i in $(seq 1 40); do
  docker compose exec -T db pg_isready -U postgres -d platform >/dev/null 2>&1 && break
  sleep 2
done
docker compose exec -T db pg_restore -U postgres -d platform --no-owner "/backups/$(basename $LATEST)"
docker compose exec -T db psql -U postgres -d platform -tAc "SELECT count(*) FROM customers;"
docker compose exec -T db psql -U postgres -d platform -tAc "SELECT count(*) FROM orders;"
```{{exec}}

Second restore, same numbers, from a document rather than from memory. **That is
the drill** — and it is worth running on a schedule, because the failure it
catches is always a change somebody made months earlier to something they did
not know was in the recovery path.

**Done when:** `RUNBOOK.md` exists with the verify-before-destroy ordering and
the expected numbers, and the restore it describes works.
