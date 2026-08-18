#!/bin/bash
# Both halves are required. A healthcheck with a plain depends_on still starts
# the app too early, and a service_healthy condition with no healthcheck is a
# Compose error rather than a wait.
fail() { echo "$1"; exit 1; }
cd /root/stack 2>/dev/null || fail "No /root/stack directory."

cfg=$(docker compose config 2>/dev/null) || fail "The Compose file is not valid. Run: docker compose config"

echo "$cfg" | grep -q 'healthcheck' \
  || fail "The db service has no healthcheck. Add one using pg_isready."

echo "$cfg" | grep -q 'service_healthy' \
  || fail "depends_on does not wait for health. Use: depends_on: { db: { condition: service_healthy } }"

id=$(docker compose ps -q db 2>/dev/null | head -1)
[ -n "$id" ] || fail "The db service is not running. Run: docker compose up -d"

status=$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$id" 2>/dev/null)
[ "$status" = "healthy" ] \
  || fail "The db container reports health '$status', not 'healthy'. Check the healthcheck command works: docker compose exec db pg_isready -U postgres -d shop"

echo "PASS"
