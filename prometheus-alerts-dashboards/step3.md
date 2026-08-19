# An alert somebody can act on

`HighErrorRate: firing` arrives at four in the morning. What does the person
holding the pager do next?

Right now: open Prometheus, work out what the expression means, guess which
service, find a dashboard, and start reading. **Every one of those steps is
something the alert could have told them.**

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
          service: prometheus
        annotations:
          summary: "Error rate {{ $value | humanize }}/s on the Prometheus API"
          description: >-
            More than 0.1 requests per second have returned 4xx or 5xx for over
            a minute. Current rate: {{ $value | humanize }}/s.
            Most likely a client sending malformed queries, or the API under
            pressure from an expensive range query.
          runbook_url: "https://egykode.com/en/labs/lab-18-custom-prometheus-alert-rules-grafana-dashboards"
          dashboard_url: "http://localhost:3000/d/api-red/api-red"
YML
curl -s -X POST http://localhost:9090/-/reload
sleep 3
curl -s http://localhost:9090/api/v1/rules \
  | jq -r '.data.groups[].rules[] | select(.name=="HighErrorRate") | .annotations'
```{{exec}}

Four annotations, each answering a question the responder would otherwise have
to ask:

- **`summary`** — what is wrong, with the number in it. `{{ $value }}` is
  rendered at fire time, so the notification carries the actual rate
- **`description`** — enough context to form a first hypothesis without opening
  anything
- **`runbook_url`** — what to do. An alert with no runbook is a request that
  somebody invent a procedure while tired
- **`dashboard_url`** — where to look next

**Labels and annotations are different things.** Labels are part of the alert's
identity: change one and Alertmanager treats it as a different alert, which is
why `severity` and `service` belong there and a rate value does not. Annotations
are free text attached to the notification and change nothing about routing.

## A dashboard with the three numbers that matter

```
cd ~/obs
mkdir -p grafana/dashboards
cat > grafana/provisioning/dashboards/all.yml <<'YML'
apiVersion: 1
providers:
  - name: default
    type: file
    options:
      path: /var/lib/grafana/dashboards
YML

cat > grafana/dashboards/api-red.json <<'JSON'
{
  "uid": "api-red",
  "title": "API RED",
  "time": { "from": "now-30m", "to": "now" },
  "panels": [
    {
      "type": "timeseries",
      "title": "Rate — requests per second",
      "gridPos": { "h": 8, "w": 8, "x": 0, "y": 0 },
      "targets": [
        { "expr": "sum(rate(prometheus_http_requests_total[2m]))", "legendFormat": "all" }
      ]
    },
    {
      "type": "timeseries",
      "title": "Errors — 4xx and 5xx per second",
      "gridPos": { "h": 8, "w": 8, "x": 8, "y": 0 },
      "targets": [
        { "expr": "sum(rate(prometheus_http_requests_total{code=~\"4..|5..\"}[2m]))", "legendFormat": "errors" }
      ]
    },
    {
      "type": "timeseries",
      "title": "Duration — p95 seconds",
      "gridPos": { "h": 8, "w": 8, "x": 16, "y": 0 },
      "targets": [
        { "expr": "histogram_quantile(0.95, sum by (le) (rate(prometheus_http_request_duration_seconds_bucket[5m])))", "legendFormat": "p95" }
      ]
    }
  ]
}
JSON

# Mount the dashboards directory into Grafana, if it is not already.
grep -q 'grafana/dashboards' compose.yaml || sed -i   's|      - ./grafana/provisioning:/etc/grafana/provisioning:ro|&
      - ./grafana/dashboards:/var/lib/grafana/dashboards:ro|'   compose.yaml
grep -A3 'grafana/provisioning' compose.yaml

docker compose up -d grafana
sleep 20
curl -s http://localhost:3000/api/dashboards/uid/api-red | jq -r '.dashboard.title, (.dashboard.panels[] | .title)'
```{{exec}}

**Rate, Errors, Duration** — the three questions you ask about any request-driven
service, and the reason the pattern has a name. A dashboard with forty panels
and none of these is a dashboard nobody uses during an incident.

Note the third one. **A latency average is nearly useless**: it hides the slow
requests inside a large number of fast ones. `histogram_quantile(0.95, ...)`
answers "how slow is it for the unluckiest one in twenty", which is the question
users actually experience.

Confirm the panels return data:

```
cd ~/obs
for Q in 'sum(rate(prometheus_http_requests_total[2m]))' \
         'sum(rate(prometheus_http_requests_total{code=~"4..|5.."}[2m]))' \
         'histogram_quantile(0.95, sum by (le) (rate(prometheus_http_request_duration_seconds_bucket[5m])))'; do
  printf "%-70s " "${Q:0:68}"
  curl -s -G http://localhost:9090/api/v1/query --data-urlencode "query=$Q" | jq -r '.data.result[0].value[1] // "no data"'
done
```{{exec}}

**Done when:** the alert carries a runbook link and a summary with context, and
the dashboard exists with rate, error and latency panels.
