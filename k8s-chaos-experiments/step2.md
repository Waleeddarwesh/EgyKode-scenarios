# The failure that does not recover

Experiment 1 was reassuring, which is why it is not the interesting one. Every
layer has something above it watching — except the top.

**Hypothesis:** deleting the Deployment takes the application down completely,
nothing brings it back, and recovery takes as long as somebody takes to notice.

```
: > /tmp/probe.log
sleep 3
START=$(date +%s)
kubectl -n chaos delete deployment web
sleep 20
kubectl -n chaos get pods
echo "failed requests: $(grep -vc 200 /tmp/probe.log) of $(wc -l < /tmp/probe.log)"
```{{exec}}

Nothing. No Pods, no replacement, and every request failing.

```
kubectl -n chaos get replicaset,pod
kubectl -n chaos get events --sort-by=.lastTimestamp | tail -4
```{{exec}}

**The cascade that protected you in experiment 1 is the thing that removed
everything here.** A Pod is replaced because a ReplicaSet is watching it; a
ReplicaSet is replaced because a Deployment is watching it. Nothing watches the
Deployment — so the failure that recovers instantly one layer down is total and
permanent one layer up.

This is the finding. The hypothesis was right, and being right about a total
outage is not comfort — it is a measured statement that your recovery time for
this class of failure is *however long it takes a human to notice and act*.

## Restore it, and time that instead

```
START=$(date +%s)
kubectl apply -f - <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  namespace: chaos
spec:
  replicas: 3
  selector:
    matchLabels: { app: web }
  template:
    metadata:
      labels: { app: web }
    spec:
      terminationGracePeriodSeconds: 30
      containers:
        - name: web
          image: nginx:1.27-alpine
          ports: [{ containerPort: 80 }]
          readinessProbe:
            httpGet: { path: /, port: 80 }
            periodSeconds: 2
          lifecycle:
            preStop:
              exec: { command: ["sh", "-c", "sleep 5"] }
YAML
kubectl -n chaos rollout status deployment/web --timeout=180s
END=$(date +%s)
echo "manual recovery took $((END - START))s from the moment somebody ran the command"
```{{exec}}

Note what that number does **not** include: noticing, deciding, finding the
manifest, and having permission to apply it. In an incident those dominate, and
they are the reason this experiment argues for something watching the
Deployment — a GitOps controller that reconciles it back — rather than for
faster typing.

```
cd /root/chaos
sed -i "0,/\*\*Result:\*\* (filled in after)/s//**Result:** Hypothesis held. Total outage, no automatic recovery. Nothing watches a Deployment, so recovery time equals human response time. Argues for continuous reconciliation./" experiments.md
tail -6 experiments.md
```{{exec}}

## The one this scenario does not repeat

A third failure worth testing is a **voluntary** disruption — a node drain
evicting more replicas than you can afford — and the control for it is a
PodDisruptionBudget. That experiment is run in full in the **node drain and
upgrade** scenario, including a drain refused by a budget, so it is not
duplicated here.

**Done when:** the Deployment is restored to 3 ready replicas and experiment 2
has a recorded result.
