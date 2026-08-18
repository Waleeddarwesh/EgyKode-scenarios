# 502 and 504 on purpose

Two gateway errors that people treat as the same thing. They are not, and the
difference tells you where to look.

**502 — nothing usable answered.** Stop both backends:

```
cd /root/proxy
docker compose stop app1 app2
curl -s -o /dev/null -w '502 test: %{http_code}\n' localhost:8080
docker compose start app1 app2
sleep 4
```{{exec}}

The connection was refused. The fault is *behind* the proxy, and the proxy is
working perfectly.

**504 — something answered, too slowly.** `proxy_read_timeout` is 5s, so a
backend that takes longer produces a gateway timeout:

```
cat >> compose.yaml <<'EOF'
  slow:
    image: alpine:3.20
    command: sh -c "apk add --no-cache socat >/dev/null && socat TCP-LISTEN:5678,fork,reuseaddr SYSTEM:'sleep 20'"
EOF

cat > conf.d/default.conf <<'EOF'
upstream backends {
    server app1:5678 max_fails=2 fail_timeout=10s;
    server app2:5678 max_fails=2 fail_timeout=10s;
}

server {
    listen 80;

    # A backend that answers, but far too slowly for the read timeout.
    location /slow {
        proxy_pass http://slow:5678;
        proxy_read_timeout 5s;
    }

    location / {
        proxy_pass http://backends;
        proxy_set_header Host              $host;
        proxy_set_header X-Real-IP         $remote_addr;
        proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_connect_timeout 2s;
        proxy_read_timeout    5s;
    }
}
EOF

docker compose up -d
docker compose restart proxy
sleep 8
curl -s -o /dev/null -w '504 test: %{http_code}
' --max-time 25 localhost:8080/slow
```{{exec}}

**You should see** `502` then `504`.

- **502** — the backend is not there. Look at the backend.
- **504** — the backend is there and did not finish in time. Look at what it
  is waiting on: a query, a lock, another service.
