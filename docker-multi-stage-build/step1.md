# A single-stage image, and why it is too big

Write the obvious Dockerfile — the one most people write first:

```
cd /root/app
cat > Dockerfile <<'DOCKER'
FROM python:3.12
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app.py .
CMD ["gunicorn", "--bind", "0.0.0.0:8000", "app:app"]
DOCKER
docker build -t app:single .
```{{exec}}

Now look at what you shipped:

```
docker images app:single
docker run --rm app:single pip --version
```{{exec}}

The image carries a full Python toolchain — `pip`, `setuptools`, the compilers
used to build wheels — none of which the running application needs.

**Done when:** the image `app:single` exists.
