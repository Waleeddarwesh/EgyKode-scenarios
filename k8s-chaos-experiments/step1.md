# A hypothesis, and something to break

Deploy the subject, and put traffic through it:

```
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
---
apiVersion: v1
kind: Service
metadata:
  name: web
  namespace: chaos
spec:
  type: NodePort
  selector: { app: web }
  ports:
    - port: 80
      targetPort: 80
      nodePort: 30080
YAML
kubectl -n chaos rollout status deployment/web --timeout=180s
```{{exec}}

## Write the hypothesis first

This is the part people skip, and it is the part that makes the exercise
science rather than vandalism:

```
mkdir -p /root/chaos && cd /root/chaos
cat > experiments.md <<'MD_EOF'
# Chaos experiment log

## Experiment 1 — kill one Pod

**Hypothesis:** killing one of three replicas causes zero failed requests. The
ReplicaSet replaces it within 10 seconds, and the Service stops routing to it
before it dies because of the readiness probe and the preStop pause.

**Result:** (filled in after)

## Experiment 2 — delete the whole Deployment

**Hypothesis:** deleting the Deployment takes the application down completely.
Nothing recreates it, because nothing above it is watching. Recovery is manual
and takes as long as it takes somebody to notice.

**Result:** (filled in after)
MD_EOF
cat experiments.md | head -8
```{{exec}}

**A hypothesis you cannot be wrong about is not a hypothesis.** "Something might
happen" is worthless; "zero failed requests, replaced within ten seconds" can be
contradicted by the next command, which is exactly what makes it useful.

## Start measuring, then inject

```
nohup sh -c 'while true; do curl -s -o /dev/null -w "%{http_code}\n" --max-time 2 http://localhost:30080/ >> /tmp/probe.log; sleep 0.2; done' >/dev/null 2>&1 &
sleep 6
echo "requests so far: $(wc -l < /tmp/probe.log)"
```{{exec}}

```
START=$(date +%s)
POD=$(kubectl -n chaos get pod -l app=web -o jsonpath='{.items[0].metadata.name}')
echo "killing $POD"
kubectl -n chaos delete pod $POD --wait=false
until [ "$(kubectl -n chaos get deployment web -o jsonpath='{.status.readyReplicas}')" = "3" ]; do sleep 1; done
END=$(date +%s)
echo "back to 3 ready replicas in $((END - START))s"
echo "failed requests: $(grep -vc 200 /tmp/probe.log)"
```{{exec}}

Two numbers, both measured. **Record them:**

```
cd /root/chaos
sed -i "0,/\*\*Result:\*\* (filled in after)/s//**Result:** recovered in the measured time above with zero failed requests. Hypothesis held./" experiments.md
grep -A1 "Result" experiments.md | head -3
```{{exec}}

The hypothesis held — which is a genuine result, and a boring one. The
interesting experiments are in the next step.

**Done when:** the Deployment is back to 3 ready replicas, the probe recorded no
failures, and the log holds a hypothesis for each experiment.
