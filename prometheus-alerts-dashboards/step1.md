# A rule, and what inactive means

```
cd ~/obs
cat > prometheus/rules/api.yml <<'YML'
groups:
  - name: api
    rules:
      - alert: HighErrorRate
        expr: sum(rate(prometheus_http_requests_total{code=~"4..|5.."}[2m])) > 0.1
        for: 1m
        labels:
          severity: warning
        annotations:
          summary: "API error rate is above 0.1 requests per second"
YML
curl -s -X POST http://localhost:9090/-/reload
sleep 3
curl -s http://localhost:9090/api/v1/rules | jq -r '.data.groups[].rules[] | select(.type=="alerting") | "\(.name): \(.state)"'
```{{exec}}

```
HighErrorRate: inactive
```

**Three states, and the difference between them is the whole subject:**

| State | Means |
| --- | --- |
| `inactive` | The expression is false. Nothing is wrong |
| `pending` | The expression is true, but not yet for as long as `for:` requires |
| `firing` | True continuously for the whole `for:` duration. Now it notifies |

Right now the expression is genuinely false — the error rate is near zero:

```
curl -s -G http://localhost:9090/api/v1/query \
  --data-urlencode 'query=sum(rate(prometheus_http_requests_total{code=~"4..|5.."}[2m]))' \
  | jq -r '.data.result[0].value[1] // "0"'
```{{exec}}

## Why the rule file is reloaded, not restarted

```
cd ~/obs
docker compose exec -T prometheus wget -q -O- http://localhost:9090/api/v1/status/config 2>/dev/null | head -c 120; echo
```{{exec}}

`--web.enable-lifecycle` is what makes `POST /-/reload` work. Without it the only
way to pick up a rule change is a restart, and a restart of Prometheus loses
every alert's *pending* state — so an alert that was thirty seconds into a
one-minute `for:` starts counting again from zero.

That matters more than it sounds: a config management system that restarts
Prometheus on every change can suppress an alert indefinitely, simply by
restarting more often than the `for:` duration.

## The expression is the alert

```
cd ~/obs
curl -s http://localhost:9090/api/v1/rules \
  | jq -r '.data.groups[].rules[] | select(.type=="alerting") | .query'
```{{exec}}

Everything else — `for:`, labels, annotations — decides *when* it notifies and
*what it says*. The expression decides whether it is true, and that is the part
worth being able to run by hand before you ever put it in a rule file.

**Done when:** the `HighErrorRate` rule is loaded and reports `inactive`.
