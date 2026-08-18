# The HPA that does nothing

```
kubectl apply -f - <<'YAML'
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: api
  namespace: platform
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: api
  minReplicas: 2
  maxReplicas: 6

  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 50

  behavior:
    scaleDown:
      stabilizationWindowSeconds: 30
YAML
sleep 20
kubectl get hpa -n platform
```{{exec}}

```
NAME   REFERENCE         TARGETS              MINPODS   MAXPODS   REPLICAS
api    Deployment/api    cpu: <unknown>/50%   2         6         2
```

**`<unknown>`.** The HPA exists, `kubectl get` lists it, nothing is wrong with
the YAML, and it will never scale anything.

```
kubectl describe hpa api -n platform | grep -A3 "Conditions:\|ScalingActive"
```{{exec}}

```
ScalingActive  False  FailedGetResourceMetric
missing request for cpu
```

**A utilization target is a percentage of the request.** No request, no
denominator, no number — the HPA cannot compute `50%` of nothing, so it declines
to act. This is the same class of failure as step 1: an object that exists,
looks like a control, and is inert.

```
kubectl set resources deployment api -n platform \
  --requests=cpu=50m,memory=64Mi --limits=cpu=200m,memory=128Mi
kubectl rollout status deployment/api -n platform --timeout=180s
sleep 45
kubectl get hpa -n platform
```{{exec}}

`cpu: 0%/50%` — a number. The denominator exists, so the HPA can do arithmetic.

## Make it scale

The api Pods have no egress rule permitting traffic *from* the load generator,
so put the load inside the api Pods themselves — the CPU is what the HPA
measures, and where it comes from does not matter:

```
for POD in $(kubectl get pods -n platform -l app=api -o jsonpath='{.items[*].metadata.name}'); do
  kubectl exec -n platform $POD -- sh -c 'for i in 1 2 3 4; do (while true; do :; done) & done' &
done
echo "burning CPU in the api Pods; watch the HPA"
sleep 90
kubectl get hpa -n platform
kubectl get pods -n platform -l app=api --no-headers | wc -l
```{{exec}}

Utilization climbs past 50% and `REPLICAS` starts rising toward 6. Watch it move:

```
kubectl get hpa api -n platform -w
```

Press `Ctrl+C` once you have seen the replica count increase.

**Scale-up is deliberately fast and scale-down deliberately slow.** By default
the HPA waits five minutes of sustained low utilization before removing a Pod,
because flapping — scaling down into a traffic dip and back up moments later —
costs more than running an extra Pod for a few minutes. The
`stabilizationWindowSeconds: 30` above shortens that so you can watch it here;
in production, leave it long.

## Stop the load

```
kubectl rollout restart deployment/api -n platform
kubectl rollout status deployment/api -n platform --timeout=180s
echo "wait for the stabilization window..."
sleep 75
kubectl get hpa -n platform
```{{exec}}

Back toward `minReplicas`.

**Done when:** the HPA reports a numeric utilization rather than `<unknown>`,
and it scaled the Deployment above `minReplicas` under load.
