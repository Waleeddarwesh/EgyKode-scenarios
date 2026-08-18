#!/bin/bash
NS=platform

kubectl get networkpolicy default-deny-all -n $NS >/dev/null 2>&1 || {
  echo "FAIL: no NetworkPolicy named default-deny-all in $NS"; exit 1; }

SEL=$(kubectl get networkpolicy default-deny-all -n $NS -o jsonpath='{.spec.podSelector}' 2>/dev/null)
[ "$SEL" = "{}" ] || {
  echo "FAIL: the policy's podSelector is '$SEL', not {} - it does not select every Pod"; exit 1; }

TYPES=$(kubectl get networkpolicy default-deny-all -n $NS -o jsonpath='{.spec.policyTypes}' 2>/dev/null)
echo "$TYPES" | grep -q Ingress || { echo "FAIL: the policy does not cover Ingress"; exit 1; }
echo "$TYPES" | grep -q Egress  || { echo "FAIL: the policy does not cover Egress"; exit 1; }

kubectl get pod stranger -n $NS >/dev/null 2>&1 || {
  echo "FAIL: the stranger Pod is missing - it is what the block is measured against"; exit 1; }
READY=$(kubectl get deployment api -n $NS -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
[ "${READY:-0}" -ge 1 ] || { echo "FAIL: the api Deployment has no ready replica"; exit 1; }

# The measurement. The policy object existing proves nothing: the API server
# stores it whether or not the network plugin implements NetworkPolicy at all.
if kubectl exec -n $NS stranger -- wget -q -O /dev/null --timeout=4 http://api >/dev/null 2>&1; then
  CNI=$(kubectl get pods -n kube-system -o custom-columns=NAME:.metadata.name --no-headers 2>/dev/null | grep -ioE "calico|cilium|weave|flannel|kindnet" | head -1)
  echo "FAIL: the stranger still reaches the api Service with default-deny applied."
  echo "      The policy is stored but nothing is enforcing it."
  echo "      This cluster's network plugin appears to be: ${CNI:-unknown}"
  echo "      Flannel does not implement NetworkPolicy; Calico, Cilium and recent kindnet do."
  exit 1
fi

echo "PASS - default-deny is applied and the stranger is genuinely blocked"
exit 0
