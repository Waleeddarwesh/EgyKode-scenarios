# Stop running as root

By default the container runs as root. If the process is compromised, so is
everything it can reach.

```
cd /root/app
docker run --rm app:multi id
```{{exec}}

`uid=0(root)`. Fix it — create a user and switch to it before `CMD`:

```
cat > Dockerfile <<'DOCKER'
FROM python:3.12 AS build
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir --target=/deps -r requirements.txt

FROM python:3.12-slim
WORKDIR /app
ENV PYTHONPATH=/deps
COPY --from=build /deps /deps
COPY app.py .
RUN useradd --create-home --uid 10001 appuser
USER appuser
CMD ["python", "-m", "gunicorn", "--bind", "0.0.0.0:8000", "app:app"]
DOCKER
docker build -t app:nonroot .
docker run --rm app:nonroot id
```{{exec}}

**Done when:** the container reports a non-zero uid and the application still
runs.
