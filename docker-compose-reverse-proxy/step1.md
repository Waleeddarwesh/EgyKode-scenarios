# The proxy, and the header it drops by default

```
cd ~/stack
cat > nginx/default.conf <<'CONF'
upstream app {
    server app:8000;
}

server {
    listen 80;
    server_name _;

    # Static files are served by nginx, from disk, and never reach Gunicorn.
    location /static/ {
        alias /usr/share/nginx/static/;
        access_log off;
        expires 1h;
    }

    location / {
        proxy_pass http://app;

        proxy_set_header Host              $host;
        proxy_set_header X-Real-IP         $remote_addr;
        proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        proxy_connect_timeout 5s;
        proxy_read_timeout    30s;
    }
}
CONF
echo written
```{{exec}}

Two jobs, split by URL.

**Static files never touch the application.** Gunicorn is a Python process with
a fixed number of workers; every worker serving a stylesheet is a worker not
serving a request. nginx reads the file and sends it, which is the thing nginx
is unreasonably good at.

**The three `proxy_set_header` lines are not boilerplate.** Without them the
application sees the proxy's address as the client address — because that is
literally true, and nothing tells it otherwise. You will watch that happen in a
moment.

## Bring up the proxy and the app

```
cd ~/stack
cat > compose.yaml <<'YAML'
services:
  app:
    image: python:3.12-alpine
    working_dir: /app
    command: sh -c "pip install --quiet gunicorn && exec gunicorn --bind 0.0.0.0:8000 --workers 2 app:application"
    volumes:
      - ./app:/app:ro
    expose:
      - "8000"

  proxy:
    image: nginx:1.27-alpine
    ports:
      - "8080:80"
    volumes:
      - ./nginx/default.conf:/etc/nginx/conf.d/default.conf:ro
      - ./static:/usr/share/nginx/static:ro
    depends_on:
      - app
YAML
docker compose up -d
sleep 25
docker compose ps
```{{exec}}

```
cd ~/stack
echo "--- static, served by nginx:"
curl -s http://localhost:8080/static/hello.txt
echo "--- proxied to gunicorn:"
curl -s http://localhost:8080/
```{{exec}}

The static file comes back, and the dynamic response shows what the application
believes about its caller:

```
remote_addr=172.x.x.x        <- the proxy container
x_real_ip=172.x.x.x          <- the actual client, because you set it
x_forwarded_for=172.x.x.x
```

`remote_addr` is the proxy. It always will be — the TCP connection genuinely
comes from nginx. **`X-Real-IP` and `X-Forwarded-For` are the only reason the
application can know otherwise**, and they exist because you set them.

Watch what happens without them:

```
cd ~/stack
sed -i '/X-Real-IP/d; /X-Forwarded-For/d' nginx/default.conf
docker compose restart proxy > /dev/null
sleep 3
curl -s http://localhost:8080/
```{{exec}}

`x_real_ip=-` and `x_forwarded_for=-`. The application now has no way at all to
know who is calling it — every rate limit, audit log and geo-block in it is
operating on the proxy's address.

Put them back:

```
cd ~/stack
sed -i 's|        proxy_set_header Host              $host;|        proxy_set_header Host              $host;\n        proxy_set_header X-Real-IP         $remote_addr;\n        proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;|' nginx/default.conf
docker compose restart proxy > /dev/null
sleep 3
curl -s http://localhost:8080/
grep proxy_set_header nginx/default.conf
```{{exec}}

**`$proxy_add_x_forwarded_for` appends rather than replaces.** Behind a second
proxy the header becomes a list, oldest first, and the client is the leftmost
entry — which is why trusting the *last* entry is a well-known way to let anyone
forge their own address.

**Done when:** `/static/hello.txt` is served by nginx and `/` returns a response
carrying a real `x_real_ip`.
