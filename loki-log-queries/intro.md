A Pod crashed at 3am. It has been replaced, and `kubectl logs` shows you the
new one. The evidence went with the old container.

Metrics tell you *that* something broke. Logs tell you *why* — but only if they
left the node before the Pod did.

**What you will do**

1. **Install the agent** that tails every Pod on the node and ships each line
   with its Kubernetes labels attached
2. **Write LogQL that selects before it scans** — the difference between a
   query that answers and one that times out
3. **Read the cause of a crash** out of a container that no longer exists

Loki and a small application are starting in the background as you read. Step 1
waits for them.

```
kubectl -n monitoring get pods; kubectl -n production get pods
```{{exec}}
