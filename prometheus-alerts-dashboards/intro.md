An alert that fires on every blip trains people to ignore it. An alert that
never fires is indistinguishable from one that does not exist. The distance
between those two is one line of YAML, and this is that line.

**What you will do**

1. **Write a rule** and read its state before anything is wrong
2. **Cause the condition** and watch the alert move `inactive` to `pending` to
   `firing` — the three states, in order, on a clock you control
3. **Remove `for:`** and see precisely how much noise it was absorbing
4. **Add the annotations** that make an alert something somebody can act on at
   four in the morning without opening a dashboard

Prometheus and Grafana are already running. Prometheus scrapes itself, so the
request metrics you will alert on are real traffic you generate:

```
curl -s http://localhost:9090/-/ready
curl -s 'http://localhost:9090/api/v1/query?query=up' | jq -r '.data.result[] | "\(.metric.job) up=\(.value[1])"'
```{{exec}}
