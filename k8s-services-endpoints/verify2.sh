#!/bin/bash
# Resolution is tested live from inside the cluster, which is the only place
# the name exists. The captured file is not trusted on its own.
fail() { echo "$1"; exit 1; }

kubectl get pod client >/dev/null 2>&1 \
  || fail "No 'client' Pod. Run: kubectl run client --image=curlimages/curl:8.10.1 --restart=Never -- sleep 3600"

phase=$(kubectl get pod client -o jsonpath='{.status.phase}' 2>/dev/null)
[ "$phase" = "Running" ] || fail "The client Pod is '$phase', not Running."

code=$(kubectl exec client -- curl -s -o /dev/null -w '%{http_code}' --max-time 10 http://web 2>/dev/null)
[ "$code" = "200" ] \
  || fail "Reaching http://web from the client Pod returned '$code'. The Service name must resolve and route inside the cluster."

# The FQDN too, because the short name working is a property of the search
# domain rather than of the Service.
fq=$(kubectl exec client -- curl -s -o /dev/null -w '%{http_code}' --max-time 10 http://web.default.svc.cluster.local 2>/dev/null)
[ "$fq" = "200" ] || fail "The fully qualified name returned '$fq'. CoreDNS should serve web.default.svc.cluster.local."

echo "PASS"
