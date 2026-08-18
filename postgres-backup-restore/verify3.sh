#!/bin/bash
D=/root/dr
cd "$D" 2>/dev/null || { echo "FAIL: no $D"; exit 1; }

[ -f RUNBOOK.md ] || { echo "FAIL: no RUNBOOK.md"; exit 1; }

for NEEDLE in "pg_restore" "pg_isready" "docker compose up -d"; do
  grep -q "$NEEDLE" RUNBOOK.md || {
    echo "FAIL: the runbook never mentions '$NEEDLE' - it does not describe the restore"; exit 1; }
done

# The ordering that matters: verify the archive before destroying the database.
# A runbook with these the other way round turns a corrupt backup into data loss.
VERIFY_LINE=$(grep -n -- "--list" RUNBOOK.md | head -1 | cut -d: -f1)
DESTROY_LINE=$(grep -n "down -v" RUNBOOK.md | head -1 | cut -d: -f1)
[ -n "$VERIFY_LINE" ] || { echo "FAIL: the runbook never verifies the archive (pg_restore --list)"; exit 1; }
[ -n "$DESTROY_LINE" ] || { echo "FAIL: the runbook never brings up a clean database"; exit 1; }
[ "$VERIFY_LINE" -lt "$DESTROY_LINE" ] || {
  echo "FAIL: the runbook destroys the database (line $DESTROY_LINE) before verifying the archive (line $VERIFY_LINE)"
  echo "      Under pressure that ordering turns a corrupt backup into permanent data loss."
  exit 1; }

# Known-good numbers, or 'it restored' is the only possible finding.
grep -q "500" RUNBOOK.md && grep -q "2000" RUNBOOK.md || {
  echo "FAIL: the runbook records no expected row counts to check a restore against"; exit 1; }

# And the documented procedure has to actually work. Following it is the test;
# reading it is not.
for i in $(seq 1 30); do
  docker compose exec -T db pg_isready -U postgres -d platform >/dev/null 2>&1 && break
  sleep 2
done
CUST=$(docker compose exec -T db psql -U postgres -d platform -tAc "SELECT count(*) FROM customers;" 2>/dev/null | tr -d '[:space:]')
ORD=$(docker compose exec -T db psql -U postgres -d platform -tAc "SELECT count(*) FROM orders;" 2>/dev/null | tr -d '[:space:]')
[ "$CUST" = "500" ] && [ "$ORD" = "2000" ] || {
  echo "FAIL: the database currently holds ${CUST:-?}/${ORD:-?} rows, expected 500/2000"
  echo "      Run the restore described in the runbook."
  exit 1; }

echo "PASS - the runbook verifies before destroying, records expected counts, and the restore it describes works"
exit 0
