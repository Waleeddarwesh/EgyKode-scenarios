Three containers that each work perfectly on their own, and a stack that fails in
ways none of them can explain.

The app reports every request as coming from `172.18.0.3`. It crashes on startup
roughly half the time. And the database it depends on loses everything the first
time somebody runs `docker compose down`.

All three are Compose problems, and all three have a specific fix.

**What you will do**

1. **Put nginx in front of Gunicorn** — static files served directly, everything
   else proxied, and the real client IP surviving the trip
2. **Make the app wait for a database that is ready**, not one that has started
3. **Prove the data survives** `down` and `up`

```
docker --version
docker compose version
ls /root/stack
```{{exec}}
