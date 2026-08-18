#!/bin/bash
SA=system:serviceaccount:team-a:viewer

kubectl get serviceaccount viewer -n team-a >/dev/null 2>&1 || {
  echo "FAIL: no ServiceAccount named viewer in team-a"; exit 1; }

# Ask the API server, not the YAML. This is the question the authoriser answers
# at request time, so it cannot pass on a Role that nothing binds.
A=$(kubectl auth can-i list pods   -n team-a --as $SA 2>/dev/null)
B=$(kubectl auth can-i list pods   -n team-b --as $SA 2>/dev/null)
D=$(kubectl auth can-i delete pods -n team-a --as $SA 2>/dev/null)

[ "$A" = "yes" ] || {
  echo "FAIL: viewer cannot list Pods in team-a - the Role exists but nothing binds it, or the names do not match"; exit 1; }
[ "$B" = "no" ] || {
  echo "FAIL: viewer can list Pods in team-b - a RoleBinding confines a grant to one namespace, so this is a ClusterRoleBinding"; exit 1; }
[ "$D" = "no" ] || {
  echo "FAIL: viewer can delete Pods in team-a - the rule grants more than reading"; exit 1; }

# Make the real request rather than asking can-i about it. `can-i get pods/log`
# answers for `pods` and reports yes while the log request is refused, so it
# would pass this step on a Role that cannot read a single log line.
OUT=$(kubectl logs web -n team-a --as $SA --tail=1 2>&1)
if echo "$OUT" | grep -qi forbidden; then
  echo "FAIL: viewer cannot read Pod logs - pods/log is a separate resource and must be named in the rule"
  exit 1
fi
if echo "$OUT" | grep -qi 'not found'; then
  # The Pod the check reads from is gone; fall back to asking properly.
  L=$(kubectl auth can-i get pods --subresource=log -n team-a --as $SA 2>/dev/null)
  [ "$L" = "yes" ] || {
    echo "FAIL: viewer cannot read Pod logs - add pods/log to the Role"; exit 1; }
fi

echo "PASS - allowed in team-a, refused in team-b, read-only, and logs readable"
exit 0
