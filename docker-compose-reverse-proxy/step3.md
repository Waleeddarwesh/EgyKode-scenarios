# Data that survives down and up

Write something worth keeping:

```
cd ~/stack
docker compose exec -T db psql -U postgres -d platform -c \
  "CREATE TABLE IF NOT EXISTS orders (id serial primary key, item text);"
docker compose exec -T db psql -U postgres -d platform -c \
  "INSERT INTO orders (item) VALUES ('a real order'), ('another one');"
docker compose exec -T db psql -U postgres -d platform -c "SELECT count(*) FROM orders;"
```{{exec}}

Two rows. Now take the stack down and bring it back:

```
cd ~/stack
docker compose down
docker compose up -d
sleep 20
docker compose exec -T db psql -U postgres -d platform -c "SELECT count(*) FROM orders;"
```{{exec}}

Still two rows.

## Why it survived, and what would have destroyed it

```
docker volume ls | grep pgdata
docker volume inspect stack_pgdata --format '{{.Mountpoint}}'
```{{exec}}

**A named volume has a lifecycle of its own.** `docker compose down` removes
containers and networks; the volume is a separate object and is left alone. The
new database container mounts the same volume and finds its data exactly where
it left it.

Three things would have lost it, and they look almost identical on the command
line:

| | Effect |
| --- | --- |
| `docker compose down` | Containers gone, **volume kept** |
| `docker compose down -v` | Containers gone, **volume deleted** |
| No `volumes:` entry at all | Data in the container layer, gone with the container |

The third is the one that catches people, because it works perfectly until the
first restart. Postgres writes to `/var/lib/postgresql/data` whether or not
anything is mounted there — into the container's writable layer, which is
deleted with the container.

Prove the difference deliberately:

```
cd ~/stack
docker compose down -v
docker volume ls | grep pgdata || echo "the volume is gone"
docker compose up -d
sleep 25
docker compose exec -T db psql -U postgres -d platform -c "SELECT count(*) FROM orders;" 2>&1 | tail -3
```{{exec}}

```
ERROR:  relation "orders" does not exist
```

**`-v` is the whole difference**, and it is one character. On a development
machine it is how you get a clean database; typed against a stack that shares a
Compose project name with something real, it is an outage.

## Put the data back

```
cd ~/stack
docker compose exec -T db psql -U postgres -d platform -c \
  "CREATE TABLE IF NOT EXISTS orders (id serial primary key, item text);"
docker compose exec -T db psql -U postgres -d platform -c \
  "INSERT INTO orders (item) VALUES ('a real order'), ('another one');"
docker compose down
docker compose up -d
sleep 20
docker compose exec -T db psql -U postgres -d platform -c "SELECT count(*) FROM orders;"
curl -s http://localhost:8080/ | head -2
```{{exec}}

Two rows again, across a full `down` and `up`, and the stack still answers.

**Done when:** the `orders` table holds two rows after the stack has been taken
down and brought back up.
