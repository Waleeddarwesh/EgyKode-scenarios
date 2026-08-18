# Data that survives

A container's filesystem is disposable. Prove it, then fix it.

Write something, destroy the stack, and look:

```
cd /root/stack
docker compose exec -T db psql -U postgres -d shop -c "CREATE TABLE orders (id int); INSERT INTO orders VALUES (1),(2),(3);"
docker compose exec -T db psql -U postgres -d shop -c "SELECT count(*) FROM orders;"
docker compose down
docker compose up -d
sleep 5
docker compose exec -T db psql -U postgres -d shop -c "SELECT count(*) FROM orders;"
```{{exec}}

The table is gone. `down` removed the container and everything written inside
it went with it.

Add a named volume and do it again:

```
cat > compose.yaml <<'EOF'
services:
  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_PASSWORD: labonly
      POSTGRES_DB: shop
    volumes:
      - pgdata:/var/lib/postgresql/data

  app:
    image: alpine:3.20
    command: sh -c "apk add --no-cache postgresql-client >/dev/null && sleep 3600"
    depends_on: [db]

volumes:
  pgdata:
EOF
docker compose up -d
sleep 6
docker compose exec -T db psql -U postgres -d shop -c "CREATE TABLE orders (id int); INSERT INTO orders VALUES (1),(2),(3);"
docker compose down
docker compose up -d
sleep 6
docker compose exec -T db psql -U postgres -d shop -c "SELECT count(*) FROM orders;"
```{{exec}}

**You should see** `3` after the restart. The data lives in the volume, which
`down` leaves alone — only `down -v` removes it.
