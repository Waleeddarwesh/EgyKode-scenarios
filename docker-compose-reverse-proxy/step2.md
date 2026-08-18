# Started is not ready

Add the database, the way most Compose files do it:

```
cd ~/stack
cat > compose.yaml <<'YAML'
services:
  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_PASSWORD: devpassword
      POSTGRES_DB: platform
    volumes:
      - pgdata:/var/lib/postgresql/data

  app:
    image: python:3.12-alpine
    working_dir: /app
    command: sh -c "pip install --quiet gunicorn && exec gunicorn --bind 0.0.0.0:8000 --workers 2 app:application"
    volumes:
      - ./app:/app:ro
    expose:
      - "8000"
    depends_on:
      - db

  proxy:
    image: nginx:1.27-alpine
    ports:
      - "8080:80"
    volumes:
      - ./nginx/default.conf:/etc/nginx/conf.d/default.conf:ro
      - ./static:/usr/share/nginx/static:ro
    depends_on:
      - app

volumes:
  pgdata:
YAML
docker compose down -v > /dev/null 2>&1
docker compose up -d > /dev/null 2>&1
docker compose ps --format '{{.Service}}	{{.Status}}'
echo "--- can the database answer yet?"
docker compose exec -T db pg_isready -U postgres -d platform 2>&1 | tail -1
```{{exec}}

```
db      Up Less than a second
app     Up Less than a second
proxy   Up Less than a second
--- can the database answer yet?
/var/run/postgresql:5432 - no response
```

Everything is `Up`. The database is not answering.

**`depends_on` with no condition waits for the container to start, not for the
process inside it to be usable.** Postgres has begun booting, is not listening
for clients yet, and Compose considers its job done.

On this machine that window is about a second — run the `pg_isready` line again
and it will succeed. That is precisely what makes it dangerous: an application
that connects on startup works nearly every time, and fails on the loaded CI
runner, or the day the database volume needs recovery and the first boot takes
longer. **Neither outcome is guaranteed**, which is the actual problem.

## Give the database a healthcheck, and wait for it

```
cd ~/stack
cat > compose.yaml <<'YAML'
services:
  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_PASSWORD: devpassword
      POSTGRES_DB: platform
    volumes:
      - pgdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres -d platform"]
      interval: 3s
      timeout: 3s
      retries: 10
      start_period: 5s

  app:
    image: python:3.12-alpine
    working_dir: /app
    command: sh -c "pip install --quiet gunicorn && exec gunicorn --bind 0.0.0.0:8000 --workers 2 app:application"
    volumes:
      - ./app:/app:ro
    expose:
      - "8000"
    depends_on:
      db:
        condition: service_healthy

  proxy:
    image: nginx:1.27-alpine
    ports:
      - "8080:80"
    volumes:
      - ./nginx/default.conf:/etc/nginx/conf.d/default.conf:ro
      - ./static:/usr/share/nginx/static:ro
    depends_on:
      - app

volumes:
  pgdata:
YAML
docker compose down > /dev/null 2>&1
time docker compose up -d
docker compose ps --format '{{.Service}}\t{{.Status}}'
```{{exec}}

The `up` took noticeably longer, and `db` now reports `(healthy)`.

Prove Compose actually waited, rather than taking your word for it:

```
cd ~/stack
DB_ID=$(docker compose ps -q db)
APP_ID=$(docker compose ps -q app)
echo "db started:  $(docker inspect -f '{{.State.StartedAt}}' $DB_ID)"
echo "app started: $(docker inspect -f '{{.State.StartedAt}}' $APP_ID)"
docker inspect -f '{{.State.Health.Status}}' $DB_ID
```{{exec}}

The app's start time is several seconds after the database's, because Compose
held it until `pg_isready` succeeded.

## The parts of a healthcheck that matter

- **`test`** — the command. `pg_isready` asks the database whether it will
  accept a connection, which is the actual question. A healthcheck that runs
  `true`, or checks a port is open, answers a different and easier one
- **`start_period`** — a grace window during which failures do not count. Without
  it a slow-starting service is marked unhealthy before it has had a chance
- **`interval` and `retries`** — how long you are prepared to wait in total.
  Three seconds times ten retries is thirty seconds before Compose gives up

**A healthcheck is only worth what its `test` asks.** `CMD-SHELL curl -f
localhost/healthz` on an app whose `/healthz` returns 200 unconditionally is a
check that a web server is running, dressed up as a check that the application
works.

**Done when:** the database declares a healthcheck, reports healthy, and the app
waits for it.
