#!/bin/bash
READY=$(kubectl get deployment web -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
[ "${READY:-0}" -eq 4 ] || { echo "FAIL: ${READY:-0} of 4 replicas are ready"; exit 1; }

# Both settings, because either one alone still drops requests.
PRESTOP=$(kubectl get deployment web -o jsonpath='{.spec.template.spec.containers[0].lifecycle.preStop}' 2>/dev/null)
[ -n "$PRESTOP" ] || {
  echo "FAIL: the container has no preStop hook - endpoint removal will race SIGTERM"; exit 1; }
PROBE=$(kubectl get deployment web -o jsonpath='{.spec.template.spec.containers[0].readinessProbe}' 2>/dev/null)
[ -n "$PROBE" ] || {
  echo "FAIL: the container has no readiness probe"; exit 1; }

kubectl get service web >/dev/null 2>&1 || { echo "FAIL: no Service named web"; exit 1; }

# The probe has to be running before the drain, or step 2 has nothing to weigh.
[ -f /tmp/probe.log ] || {
  echo "FAIL: /tmp/probe.log does not exist - start the background probe"; exit 1; }
LINES=$(wc -l < /tmp/probe.log)
[ "$LINES" -ge 10 ] || {
  echo "FAIL: only $LINES requests recorded - is the probe still running?"; exit 1; }
OK=$(grep -c 200 /tmp/probe.log)
[ "$OK" -ge 10 ] || {
  echo "FAIL: the probe recorded $OK successful requests out of $LINES - the Service is not answering"; exit 1; }

WORKER=$(kubectl get nodes -l '!node-role.kubernetes.io/control-plane' -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
SCHED=$(kubectl get node "$WORKER" -o jsonpath='{.spec.unschedulable}' 2>/dev/null)
[ "$SCHED" = "true" ] || { echo "FAIL: node $WORKER is not cordoned"; exit 1; }

echo "PASS - four ready replicas, traffic recording, worker cordoned"
exit 0
