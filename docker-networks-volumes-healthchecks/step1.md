# Names, not addresses

Containers get new IP addresses every time they start. Compose puts services on
a shared network with a DNS name each, so nothing has to know an address.

```
cd /root/stack
cat > compose.yaml <<'EOF'
services:
  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_PASSWORD: labonly
      POSTGRES_DB: shop

  app:
    image: alpine:3.20
    command: sh -c "apk add --no-cache postgresql-client >/dev/null && sleep 3600"
    depends_on: [db]
EOF
docker compose up -d
docker compose ps
```{{exec}}

Now reach the database **by name** from the app container:

```
docker compose exec app sh -c 'nc -z db 5432 && echo "reached db by name"'
```{{exec}}

**You should see** the connection succeed. `db` resolves because Compose put
both services on the same network and registered the name — no `links`, no IP,
nothing to update when the container restarts.
