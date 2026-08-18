# Two backends behind one proxy

```
cd /root/proxy
mkdir -p conf.d
cat > conf.d/default.conf <<'EOF'
upstream backends {
    server app1:5678 max_fails=2 fail_timeout=10s;
    server app2:5678 max_fails=2 fail_timeout=10s;
}

server {
    listen 80;
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

cat > compose.yaml <<'EOF'
services:
  app1:
    image: hashicorp/http-echo:1.0
    command: ["-listen=:5678", "-text=backend one"]
  app2:
    image: hashicorp/http-echo:1.0
    command: ["-listen=:5678", "-text=backend two"]
  proxy:
    image: nginx:1.27-alpine
    ports: ["8080:80"]
    volumes:
      # The directory, not the file. A single-file bind mount binds the
      # inode, and any editor that writes-and-renames (sed -i, vim) leaves
      # the container holding the old file while the host shows the new one.
      - ./conf.d:/etc/nginx/conf.d:ro
    depends_on: [app1, app2]
EOF
docker compose up -d
sleep 8
for i in $(seq 1 6); do curl -s localhost:8080; done
```{{exec}}

**You should see** both backends answering, alternating. Round robin is the
default — no directive needed.

Those four `proxy_set_header` lines are not decoration. Without them the
application sees the proxy as the client: every log line records the proxy's
IP, redirects are built against the proxy's hostname, and the app believes the
request arrived over HTTP.
