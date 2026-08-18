#!/bin/bash
NS=platform

kubectl get hpa api -n $NS >/dev/null 2>&1 || { echo "FAIL: no HorizontalPodAutoscaler named api"; exit 1; }

# The reason an HPA does nothing: a utilization target is a percentage of the
# request, and without a request there is no denominator.
REQ=$(kubectl get deployment api -n $NS -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}' 2>/dev/null)
[ -n "$REQ" ] || {
  echo "FAIL: the api container has no CPU request, so the HPA cannot compute a percentage"
  echo "      kubectl set resources deployment api -n platform --requests=cpu=50m,memory=64Mi"
  exit 1; }

# ScalingActive is the condition that separates a working HPA from a decorative
# one. It is False with FailedGetResourceMetric when the metric cannot be read.
ACTIVE=$(kubectl get hpa api -n $NS -o jsonpath='{.status.conditions[?(@.type=="ScalingActive")].status}' 2>/dev/null)
[ "$ACTIVE" = "True" ] || {
  REASON=$(kubectl get hpa api -n $NS -o jsonpath='{.status.conditions[?(@.type=="ScalingActive")].message}' 2>/dev/null)
  echo "FAIL: the HPA is not active: ${REASON:-no ScalingActive condition yet}"
  echo "      If metrics-server has just started, wait a minute and check again."
  exit 1; }

# A numeric current utilization, which is what <unknown> is not.
CUR=$(kubectl get hpa api -n $NS -o jsonpath='{.status.currentMetrics[0].resource.current.averageUtilization}' 2>/dev/null)
echo "$CUR" | grep -qE '^[0-9]+$' || {
  echo "FAIL: the HPA reports no numeric utilization yet (got '${CUR:-<unknown>}')"; exit 1; }

MIN=$(kubectl get hpa api -n $NS -o jsonpath='{.spec.minReplicas}' 2>/dev/null)
DESIRED=$(kubectl get hpa api -n $NS -o jsonpath='{.status.desiredReplicas}' 2>/dev/null)
CURRENT=$(kubectl get deployment api -n $NS -o jsonpath='{.spec.replicas}' 2>/dev/null)

# Evidence it actually scaled. Checking only "the HPA is active" would pass on
# an autoscaler that has never moved a Pod in its life.
SCALED=no
[ "${DESIRED:-0}" -gt "${MIN:-2}" ] && SCALED=yes
[ "${CURRENT:-0}" -gt "${MIN:-2}" ] && SCALED=yes
kubectl get events -n $NS --field-selector reason=SuccessfulRescale 2>/dev/null | grep -q "New size" && SCALED=yes

[ "$SCALED" = "yes" ] || {
  echo "FAIL: the HPA is working but has never scaled above minReplicas ($MIN)."
  echo "      Start the CPU load from the step and check again while it is running."
  echo "      Current: utilization ${CUR}%, replicas ${CURRENT}, desired ${DESIRED}"
  exit 1; }

echo "PASS - the HPA reads ${CUR}% utilization and has scaled above minReplicas"
exit 0
