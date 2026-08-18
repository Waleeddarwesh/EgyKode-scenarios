#!/bin/bash
# A small Python app with a compiled dependency, so the multi-stage split has
# something real to remove. Deliberately not Django: the lesson is the image
# layout, and a 200MB framework download would spend the session on pip.
set -e
mkdir -p /root/app && cd /root/app

cat > requirements.txt <<'REQ'
gunicorn==22.0.0
REQ

cat > app.py <<'PY'
def app(environ, start_response):
    start_response("200 OK", [("Content-Type", "text/plain")])
    return [b"ok\n"]
PY

echo "App ready at /root/app"
