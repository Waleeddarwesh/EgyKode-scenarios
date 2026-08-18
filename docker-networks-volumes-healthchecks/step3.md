# Started is not ready

`depends_on` waits for a container to **start**. Postgres accepts connections
several seconds after that, so an application that connects immediately fails —
and works on the second try, which is why this bug survives so long.

Add a healthcheck, and make the dependency wait for it:

```
cd /root/stack
cat > compose.yaml <<'EOF'
services:
  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_PASSWORD: labonly
      POSTGRES_DB: shop
    volumes:
      - pgdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres -d shop"]
      interval: 3s
      timeout: 3s
      retries: 10
      start_period: 5s

  app:
    image: alpine:3.20
    command: sh -c "apk add --no-cache postgresql-client >/dev/null && sleep 3600"
    depends_on:
      db:
        condition: service_healthy

volumes:
  pgdata:
EOF
docker compose down
docker compose up -d
docker compose ps
```{{exec}}

Confirm the database reports healthy rather than merely running:

```
docker inspect --format '{{.State.Health.Status}}' $(docker compose ps -q db)
```{{exec}}

**You should see** `healthy`. `condition: service_healthy` is what turns
`depends_on` from "it exists" into "it works".
