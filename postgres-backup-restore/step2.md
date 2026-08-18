# Lose it, and measure the recovery

A backup that has never been restored is a hypothesis. Test it the only way that
counts — by destroying the database.

Note what you are about to lose:

```
cd ~/dr
docker compose exec -T db psql -U postgres -d platform -tAc "SELECT count(*) FROM customers;"
docker compose exec -T db psql -U postgres -d platform -tAc "SELECT count(*) FROM orders;"
docker compose exec -T db psql -U postgres -d platform -tAc "SELECT sum(total)::numeric(12,2) FROM orders;"
```{{exec}}

500 customers, 2000 orders, and a total. That last number is the one to write
down: **row counts tell you a restore ran, and a checksum tells you it restored
the right data.**

## Destroy it

```
cd ~/dr
docker compose down -v
docker volume ls | grep pgdata || echo "the data volume is gone"
```{{exec}}

That is the whole database, deleted, exactly as a bad `-v`, a failed upgrade or
a corrupted filesystem would leave you.

## Recover, and time it

**Start the clock.** Real recovery time includes everything — starting the
service, waiting for it to be ready, restoring, and confirming — not just the
`pg_restore` line:

```
cd ~/dr
START=$(date +%s)
echo "$START" > /tmp/rto_start

docker compose up -d
for i in $(seq 1 40); do
  docker compose exec -T db pg_isready -U postgres -d platform >/dev/null 2>&1 && break
  sleep 2
done
echo "database is accepting connections"
```{{exec}}

The database is back, and empty. Restore into it:

```
cd ~/dr
LATEST=$(ls -t backups/platform-*.dump | head -1)
echo "restoring $LATEST"
docker compose exec -T db pg_restore -U postgres -d platform --no-owner "/backups/$(basename $LATEST)"
docker compose exec -T db psql -U postgres -d platform -tAc "SELECT count(*) FROM customers;"
docker compose exec -T db psql -U postgres -d platform -tAc "SELECT count(*) FROM orders;"
docker compose exec -T db psql -U postgres -d platform -tAc "SELECT sum(total)::numeric(12,2) FROM orders;"
```{{exec}}

Same counts, same total.

```
cd ~/dr
END=$(date +%s)
RTO=$((END - $(cat /tmp/rto_start)))
echo "$RTO" > rto_seconds
echo "measured RTO: ${RTO}s"
```{{exec}}

**That number is your RTO for this database at this size**, and it is the only
honest one you have. It will grow roughly with the data, so a figure measured on
500 rows tells you the shape of the process rather than the production number —
which is exactly why the drill is repeated against a realistic restore.

## RTO and RPO are different promises

| | Question | Set by |
| --- | --- | --- |
| **RTO** | How long until we are back? | How fast the restore runs |
| **RPO** | How much data may we lose? | **How often you back up** |

Nothing you did just now improved the RPO. A nightly backup means an RPO of up
to 24 hours no matter how quickly you restore it — the data written since the
last dump is simply gone.

```
cd ~/dr
echo "backup schedule: nightly at 02:00" > rpo.txt
echo "implied RPO: up to 24 hours of writes" >> rpo.txt
echo "measured RTO: $(cat rto_seconds)s at this data size" >> rpo.txt
cat rpo.txt
```{{exec}}

Writing both down is the point. **"We have backups" is not a recovery objective**
— a number somebody measured is.

**Done when:** the data is restored with matching counts, and `rto_seconds`
holds a measured number.
