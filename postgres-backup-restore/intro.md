Everybody has backups. Far fewer have restores.

The difference shows up exactly once, at the worst possible moment, and the
usual discovery is that the backup has been failing quietly for weeks, or is
technically fine and takes six hours, or restores perfectly into a database
nobody can reach.

**What you will do**

1. **Take a backup and prove it is restorable** — before you need it, which is
   the only time proving it is cheap
2. **Catch a corrupted backup** that looks completely normal on disk
3. **Destroy the database and bring it back**, timing the whole thing, so "our
   RTO is an hour" becomes a number you measured rather than one somebody hoped
4. **Write the runbook** you used, so the next person is not you at 3am

A database is already running with 500 customers and 2000 orders:

```
cd ~/dr
docker compose exec -T db psql -U postgres -d platform -c "SELECT count(*) FROM customers;"
docker compose exec -T db psql -U postgres -d platform -c "SELECT count(*) FROM orders;"
```{{exec}}
