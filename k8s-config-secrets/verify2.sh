#!/bin/bash
NS=platform

PROBE=$(kubectl get deployment api -n $NS -o jsonpath='{.spec.template.spec.containers[0].readinessProbe.httpGet.path}' 2>/dev/null)
[ -n "$PROBE" ] || { echo "FAIL: the api container has no readiness probe"; exit 1; }

NOTREADY=$(kubectl get pod -n $NS -l app=api --no-headers 2>/dev/null | awk '$2 == "0/1"' | wc -l)
[ "$NOTREADY" -eq 1 ] || {
  echo "FAIL: expected exactly 1 Pod failing readiness, found $NOTREADY"; exit 1; }

# The whole point: it left the Service without being restarted. A liveness
# probe here would show RESTARTS climbing, and that is the mistake this step
# exists to rule out.
RESTARTS=$(kubectl get pod -n $NS -l app=api --no-headers | awk '$2 == "0/1" {print $4}')
[ "$RESTARTS" = "0" ] || {
  echo "FAIL: the unready Pod has restarted ($RESTARTS) - readiness must not restart a container"; exit 1; }

READY_EPS=$(kubectl get endpointslice -n $NS -l kubernetes.io/service-name=api -o jsonpath='{.items[*].endpoints[*].conditions.ready}' 2>/dev/null | grep -o true | wc -l)
[ "$READY_EPS" -eq 1 ] || {
  echo "FAIL: the Service has $READY_EPS ready endpoint(s), expected 1"; exit 1; }

echo "PASS - the Pod left the Service and kept running"
exit 0
