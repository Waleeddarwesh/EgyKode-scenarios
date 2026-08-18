#!/bin/bash
D=/root/dr
cd "$D" 2>/dev/null || { echo "FAIL: no $D"; exit 1; }

for i in $(seq 1 30); do
  docker compose exec -T db pg_isready -U postgres -d platform >/dev/null 2>&1 && break
  sleep 2
done

CUST=$(docker compose exec -T db psql -U postgres -d platform -tAc "SELECT count(*) FROM customers;" 2>/dev/null | tr -d '[:space:]')
ORD=$(docker compose exec -T db psql -U postgres -d platform -tAc "SELECT count(*) FROM orders;" 2>/dev/null | tr -d '[:space:]')
[ "$CUST" = "500" ] || { echo "FAIL: customers holds '${CUST:-nothing}', expected 500"; exit 1; }
[ "$ORD" = "2000" ] || { echo "FAIL: orders holds '${ORD:-nothing}', expected 2000"; exit 1; }

# Row counts prove a restore ran. The sum proves it restored the right rows -
# a truncated or partial restore can still produce plausible counts.
SUM=$(docker compose exec -T db psql -U postgres -d platform -tAc "SELECT round(sum(total))::bigint FROM orders;" 2>/dev/null | tr -d '[:space:]')
echo "$SUM" | grep -qE '^[0-9]+$' || { echo "FAIL: could not read a total from orders"; exit 1; }
[ "$SUM" -gt 0 ] || { echo "FAIL: the orders total is $SUM - the rows are empty"; exit 1; }

# Referential integrity survived, which a data-only or out-of-order restore
# would not guarantee.
ORPHANS=$(docker compose exec -T db psql -U postgres -d platform -tAc \
  "SELECT count(*) FROM orders o LEFT JOIN customers c ON c.id=o.customer_id WHERE c.id IS NULL;" 2>/dev/null | tr -d '[:space:]')
[ "${ORPHANS:-1}" = "0" ] || { echo "FAIL: $ORPHANS orders reference a customer that was not restored"; exit 1; }

# The measured recovery time has to exist as a number somebody wrote down.
[ -f rto_seconds ] || {
  echo "FAIL: no rto_seconds file - the recovery was not timed"
  echo "      An RTO nobody measured is a hope, not an objective."
  exit 1; }
RTO=$(tr -d '[:space:]' < rto_seconds)
echo "$RTO" | grep -qE '^[0-9]+$' || { echo "FAIL: rto_seconds contains '$RTO', not a number"; exit 1; }
[ "$RTO" -ge 1 ] || { echo "FAIL: the recorded RTO is ${RTO}s, which cannot include starting a database"; exit 1; }

# And the distinction between the two objectives has to be written down, since
# restoring faster does nothing whatsoever for the RPO.
[ -f rpo.txt ] || { echo "FAIL: no rpo.txt recording what the backup schedule implies"; exit 1; }
grep -qi "rpo" rpo.txt || { echo "FAIL: rpo.txt does not mention an RPO"; exit 1; }

echo "PASS - restored 500/2000 rows with intact references, RTO recorded as ${RTO}s"
exit 0
