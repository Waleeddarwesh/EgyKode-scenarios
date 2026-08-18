# Split the build from the runtime

Install the dependencies in one stage, copy only the result into another:

```
cd /root/app
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
CMD ["python", "-m", "gunicorn", "--bind", "0.0.0.0:8000", "app:app"]
DOCKER
docker build -t app:multi .
```{{exec}}

Compare them:

```
docker images | grep '^app'
```{{exec}}

The build stage is not shipped. Only `/deps` crosses over.

**Done when:** `app:multi` exists and is meaningfully smaller than `app:single`.
