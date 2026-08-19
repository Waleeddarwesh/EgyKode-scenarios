Everything so far queried a container that is still running. The reason
centralised logging exists is the other case.

## Break something

```
kubectl -n production create deployment crasher --image=busybox:1.36 -- \
  sh -c 'echo "FATAL: config key DATABASE_URL missing" >&2; exit 1'
sleep 60
kubectl -n production get pods -l app=crasher
```{{exec}}

`CrashLoopBackOff`. Now try to find out why, the way you would at 3am.

```
kubectl -n production logs deploy/crasher
```{{exec}}

Depending on where in the backoff cycle you landed, that is either the message
or an error saying the container is waiting to start. Kubernetes keeps the
current container and, if you ask for it, the one immediately before:

```
kubectl -n production logs deploy/crasher --previous
```{{exec}}

**One container back. That is the entire budget.** The crash from five minutes
ago is gone, and if the Pod had been rescheduled onto another node, `--previous`
could not reach it at all.

## Ask Loki instead

```
curl -sG localhost:31000/loki/api/v1/query_range \
  --data-urlencode 'query={namespace="production", app="crasher"}' \
  --data-urlencode 'since=30m' --data-urlencode 'limit=100' \
  | grep -o 'FATAL[^"]*' | sort | uniq -c
```{{exec}}

Every restart, in order, including the containers Kubernetes has already
discarded. The count is how many times it has crashed since you created it.

Promtail read those lines off the node's disk as they were written. By the time
the container was gone, the evidence had already left.

## Record what you found

The point of a log store is answering the question, so answer it:

```
cat > /root/cause.txt <<'EOF'
PUT THE MESSAGE YOU FOUND HERE
EOF
```{{exec}}

## Retention, before it costs you

Logs grow without limit by default. This environment sets seven days:

```
limits_config:
  retention_period: 168h
compactor:
  retention_enabled: true
```

Long enough for an investigation, short enough to bound the bill. Pick the
number deliberately, because the alternative is that the invoice picks it.
