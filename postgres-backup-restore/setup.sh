#!/bin/bash
mkdir -p /root/dr/backups
cat > /root/dr/compose.yaml <<'YAML'
services:
  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_PASSWORD: devpassword
      POSTGRES_DB: platform
    volumes:
      - pgdata:/var/lib/postgresql/data
      - ./backups:/backups
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres -d platform"]
      interval: 3s
      timeout: 3s
      retries: 10
      start_period: 5s

volumes:
  pgdata:
YAML

docker pull -q postgres:16-alpine >/dev/null 2>&1
cd /root/dr && docker compose up -d >/dev/null 2>&1

for i in $(seq 1 40); do
  docker compose -f /root/dr/compose.yaml exec -T db pg_isready -U postgres -d platform >/dev/null 2>&1 && break
  sleep 2
done

# Something worth losing.
docker compose -f /root/dr/compose.yaml exec -T db psql -U postgres -d platform >/dev/null 2>&1 <<'SQL'
CREATE TABLE customers (id serial primary key, name text, created timestamptz default now());
INSERT INTO customers (name)
SELECT 'customer-' || g FROM generate_series(1, 500) g;
CREATE TABLE orders (id serial primary key, customer_id int references customers(id), total numeric);
INSERT INTO orders (customer_id, total)
SELECT (random()*499)::int + 1, round((random()*900 + 10)::numeric, 2) FROM generate_series(1, 2000);
SQL

echo done
