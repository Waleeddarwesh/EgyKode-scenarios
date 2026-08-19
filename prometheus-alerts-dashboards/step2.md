# Pending, then firing

Cause the condition. This sends a bad query twice a second for three minutes, in
the background, so you can watch the alert move while it runs:

```
cd ~/obs
nohup sh -c 'for i in $(seq 1 360); do curl -s -o /dev/null -G http://localhost:9090/api/v1/query --data-urlencode "query=(("; sleep 0.5; done' >/dev/null 2>&1 &
echo "generating errors for three minutes"
sleep 20
curl -s -G http://localhost:9090/api/v1/query \
  --data-urlencode 'query=sum(rate(prometheus_http_requests_total{code=~"4..|5.."}[2m]))' \
  | jq -r '.data.result[0].value[1]'
```{{exec}}

The error rate is above `0.1`, so the expression is true. Watch the state:

```
for i in $(seq 1 10); do
  printf "%s  " "$(date +%H:%M:%S)"
  curl -s http://localhost:9090/api/v1/rules \
    | jq -r '.data.groups[].rules[] | select(.name=="HighErrorRate") | .state'
  sleep 10
done
```{{exec}}

```
01:41:10  pending
01:41:20  pending
01:41:30  pending
01:41:40  pending
01:41:50  pending
01:42:00  firing
```

**`pending` for a full minute, then `firing`.** That minute is the `for: 1m`,
and nothing was notified during it. An alertmanager attached to this Prometheus
would have received nothing until the last line.

```
curl -s http://localhost:9090/api/v1/alerts \
  | jq -r '.data.alerts[] | "\(.labels.alertname) \(.state) since \(.activeAt)"'
```{{exec}}

## Now take `for:` away

```
cd ~/obs
sed -i '/for: 1m/d' prometheus/rules/api.yml
curl -s -X POST http://localhost:9090/-/reload
sleep 8
curl -s http://localhost:9090/api/v1/rules \
  | jq -r '.data.groups[].rules[] | select(.name=="HighErrorRate") | "\(.name): \(.state) for=\(.duration)"'
```{{exec}}

`for=0`, and the alert is `firing` immediately — no pending state at all.

That looks like a faster alert. It is a noisier one. **With `for: 0` the alert
fires on a single evaluation**, which means a five-second blip, one slow scrape,
or a deploy that briefly returns errors all page somebody. Stop the load and
watch how fast it clears:

```
pkill -f "query=((" 2>/dev/null
sleep 15
curl -s http://localhost:9090/api/v1/rules \
  | jq -r '.data.groups[].rules[] | select(.name=="HighErrorRate") | .state'
```{{exec}}

An alert that fires and resolves within a minute is the definition of pager
noise: nobody can act on it, it is always resolved by the time it is opened, and
after the third one people stop opening them.

**`for:` is a statement about how long a problem must persist before it is worth
a human.** It is not a delay to be minimised — a five-minute `for:` on a
capacity alert and a thirty-second one on a total outage are both correct.

## Put it back

```
cd ~/obs
sed -i 's|^        expr: .*|&
        for: 1m|' prometheus/rules/api.yml
grep -A2 "expr:" prometheus/rules/api.yml
curl -s -X POST http://localhost:9090/-/reload
sleep 3
curl -s http://localhost:9090/api/v1/rules | jq -r '.data.groups[].rules[] | select(.name=="HighErrorRate") | "for=\(.duration)s"'
```{{exec}}

**Done when:** the alert reached `firing` under load, and `for:` is back in the
rule.
