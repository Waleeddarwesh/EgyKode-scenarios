#!/bin/bash
NS=platform

kubectl get networkpolicy default-deny-all -n $NS >/dev/null 2>&1 || {
  echo "FAIL: the default-deny policy is gone - deleting it is not how you allow traffic"; exit 1; }

# By hostname, which needs both the DNS rule and the database rule. Testing by
# IP would pass with DNS still blocked, which is the trap the step is about.
if ! kubectl exec -n $NS deploy/api -- wget -q -O /dev/null --timeout=6 http://db:5432 >/dev/null 2>&1; then
  echo "FAIL: the api cannot reach http://db:5432 by hostname."
  DB_IP=$(kubectl get pod -n $NS -l app=postgres -o jsonpath='{.items[0].status.podIP}' 2>/dev/null)
  if [ -n "$DB_IP" ] && kubectl exec -n $NS deploy/api -- wget -q -O /dev/null --timeout=6 http://$DB_IP:5432 >/dev/null 2>&1; then
    echo "      It reaches the same Pod by IP, so the database rule is fine and DNS is not."
    echo "      Allow egress to k8s-app=kube-dns in kube-system, on UDP 53 and TCP 53."
  else
    echo "      It cannot reach the database by IP either - check the db ingress policy."
  fi
  exit 1
fi

# Both directions must be declared. Egress alone leaves the connection allowed
# out and dropped on arrival, which happens to work here only if the db has no
# policy selecting it - so check the object, not just the outcome.
kubectl get networkpolicy -n $NS -o jsonpath='{.items[*].spec.podSelector.matchLabels.app}' 2>/dev/null | grep -q postgres || {
  echo "FAIL: no policy selects the database - it is currently protected only by the default-deny"
  exit 1; }

DNS=$(kubectl get networkpolicy -n $NS -o jsonpath='{.items[*].spec.egress[*].ports[*].port}' 2>/dev/null)
echo "$DNS" | grep -q 53 || { echo "FAIL: no egress rule permits port 53"; exit 1; }

# And the block must still hold for everything else. An allow-all would satisfy
# every check above.
if kubectl exec -n $NS stranger -- wget -q -O /dev/null --timeout=4 http://api >/dev/null 2>&1; then
  echo "FAIL: the stranger can still reach the api - the allow rules are wider than intended"; exit 1; fi
if kubectl exec -n $NS stranger -- wget -q -O /dev/null --timeout=4 http://db:5432 >/dev/null 2>&1; then
  echo "FAIL: the stranger can still reach the database"; exit 1; fi

echo "PASS - the api reaches its database by name, and the stranger reaches nothing"
exit 0
