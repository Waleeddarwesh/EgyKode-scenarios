#!/bin/bash
mkdir -p /root/stack/app /root/stack/static /root/stack/nginx

# The application: a real WSGI app behind real Gunicorn, small enough to read.
cat > /root/stack/app/app.py <<'PY'
import os


def application(environ, start_response):
    path = environ.get("PATH_INFO", "/")

    if path == "/healthz":
        start_response("200 OK", [("Content-Type", "text/plain")])
        return [b"ok\n"]

    # What the app believes about who is calling it.
    body = "remote_addr={}\nx_real_ip={}\nx_forwarded_for={}\nhost={}\n".format(
        environ.get("REMOTE_ADDR", "-"),
        environ.get("HTTP_X_REAL_IP", "-"),
        environ.get("HTTP_X_FORWARDED_FOR", "-"),
        environ.get("HTTP_HOST", "-"),
    )
    start_response("200 OK", [("Content-Type", "text/plain")])
    return [body.encode()]
PY

echo "served by nginx, never by gunicorn" > /root/stack/static/hello.txt

# Pre-pull so no step waits on a registry.
docker pull -q nginx:1.27-alpine >/dev/null 2>&1
docker pull -q postgres:16-alpine >/dev/null 2>&1
docker pull -q python:3.12-alpine >/dev/null 2>&1

echo done
