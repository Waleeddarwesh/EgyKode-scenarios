#!/bin/bash
# Reads the cluster. It creates nothing, so the check cannot pass on its own
# side effects.
fail() { echo "$1"; exit 1; }

kubectl get svc web >/dev/null 2>&1 \
  || fail "No Service called 'web' yet. Run: kubectl expose deployment web --port=80 --target-port=80 --name=web"

type=$(kubectl get svc web -o jsonpath='{.spec.type}' 2>/dev/null)
[ "$type" = "ClusterIP" ] || fail "The 'web' Service is type '$type'. This step wants a ClusterIP."

# The endpoint list is the actual claim: a Service with no endpoints is a name
# pointing at nothing, and it looks perfectly healthy from `get svc`.
count=$(kubectl get endpointslice -l kubernetes.io/service-name=web \
        -o jsonpath='{range .items[*]}{range .endpoints[*]}{.addresses[0]}{"\n"}{end}{end}' 2>/dev/null | grep -c . || true)
[ "$count" -eq 0 ] && count=$(kubectl get endpoints web -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null | wc -w)

[ "$count" -ge 3 ] \
  || fail "The Service has $count endpoint(s), not 3. Check the Deployment has 3 ready replicas and that the Service selector matches their labels."

echo "PASS"
