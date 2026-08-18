#!/bin/bash
# Causes the failure itself rather than trusting a note, then restores the
# cluster. A scenario that leaves the Service broken fails the next learner.
fail() { echo "$1"; exit 1; }

kubectl get svc web >/dev/null 2>&1 || fail "No 'web' Service."

# It must be healthy to begin with, or the step was left half-finished.
before=$(kubectl get endpoints web -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null | wc -w)
[ "$before" -ge 1 ] \
  || fail "The Service currently has no endpoints. Restore the selector and remove the failing readiness probe before verifying."

sel=$(kubectl get svc web -o jsonpath='{.spec.selector.app}' 2>/dev/null)
[ "$sel" = "web" ] || fail "The Service selector is 'app=$sel'. Put it back to 'app=web'."

# Cause one, live: a selector that matches nothing empties the list.
kubectl patch svc web -p '{"spec":{"selector":{"app":"egykode-check-nomatch"}}}' >/dev/null 2>&1
sleep 3
empty=$(kubectl get endpoints web -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null | wc -w)
kubectl patch svc web -p '{"spec":{"selector":{"app":"web"}}}' >/dev/null 2>&1
sleep 3
restored=$(kubectl get endpoints web -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null | wc -w)

[ "$empty" -eq 0 ] \
  || fail "Changing the selector to something nothing matches left $empty endpoint(s). The Service is not selecting by label as expected."
[ "$restored" -ge 1 ] \
  || fail "The endpoint list did not come back after restoring the selector. Check the Pods are still ready."

# The learner's own record of both causes.
[ -s /root/manifests/empty-endpoints.txt ] \
  || fail "No /root/manifests/empty-endpoints.txt. Record both causes as the step describes."
grep -qi 'selector' /root/manifests/empty-endpoints.txt \
  || fail "The record does not mention the selector cause."
grep -qiE 'ready|readiness' /root/manifests/empty-endpoints.txt \
  || fail "The record does not mention the readiness cause."

echo "PASS"
