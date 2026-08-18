# Lose a backend without losing the client

Stop one and keep asking:

```
cd /root/proxy
docker compose stop app1
for i in $(seq 1 8); do curl -s -o /dev/null -w '%{http_code} ' localhost:8080; done; echo
for i in $(seq 1 4); do curl -s localhost:8080; done
```{{exec}}

**You should see** every response `200`, all of them from `backend two`.

`max_fails=2 fail_timeout=10s` is a **passive** health check: nginx marks a
backend unavailable after two failures and retries it ten seconds later. It is
driven by real traffic rather than a separate probe, which means it costs
nothing and reacts only when something actually breaks.

Bring it back and confirm both return:

```
docker compose start app1
sleep 12
for i in $(seq 1 6); do curl -s localhost:8080; done
```{{exec}}
