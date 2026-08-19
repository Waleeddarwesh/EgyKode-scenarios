#!/bin/bash
NS=routing

kubectl -n $NS get ingress legacy >/dev/null 2>&1 || { echo "FAIL: no Ingress named legacy in $NS"; exit 1; }
kubectl -n $NS get gateway shop >/dev/null 2>&1 || { echo "FAIL: no Gateway named shop in $NS"; exit 1; }
kubectl -n $NS get httproute app >/dev/null 2>&1 || { echo "FAIL: no HTTPRoute named app in $NS"; exit 1; }

# An Ingress with no controller behind it lists cleanly and routes nothing. The
# ADDRESS column is written when a controller adopts it.
# The controller takes up to about ninety seconds to publish this, so wait
# rather than reading it once - but still fail if it never appears.
for i in $(seq 1 20); do
  ADDR=$(kubectl -n $NS get ingress legacy -o jsonpath='{.status.loadBalancer.ingress[0].ip}{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
  [ -n "$ADDR" ] && break
  sleep 6
done
[ -n "$ADDR" ] || {
  echo "FAIL: the Ingress has no address - no controller has adopted it"
  echo "      Check ingressClassName matches an installed IngressClass."
  exit 1; }

# The Gateway must be accepted and programmed, which is the equivalent signal.
PROG=$(kubectl -n $NS get gateway shop -o jsonpath='{.status.conditions[?(@.type=="Programmed")].status}' 2>/dev/null)
[ "$PROG" = "True" ] || { echo "FAIL: the Gateway is not Programmed (got '${PROG:-none}')"; exit 1; }

# And the route must actually be attached to it. An HTTPRoute whose parentRef
# does not resolve is accepted by the API and serves nothing.
PARENT=$(kubectl -n $NS get httproute app -o jsonpath='{.status.parents[0].conditions[?(@.type=="Accepted")].status}' 2>/dev/null)
[ "$PARENT" = "True" ] || { echo "FAIL: the HTTPRoute is not Accepted by its parent Gateway"; exit 1; }

IP=$(kubectl -n ingress-nginx get svc ingress-nginx-controller -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null)
GP=$(kubectl -n nginx-gateway get svc nginx-gateway -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null)
[ -n "$IP" ] && [ -n "$GP" ] || { echo "FAIL: could not find the controller node ports"; exit 1; }

# Both data paths have to actually serve the application.
A=$(curl -s --max-time 10 -H 'Host: legacy.example.com' http://localhost:$IP/ 2>/dev/null | tr -d '[:space:]')
B=$(curl -s --max-time 10 -H 'Host: shop.example.com' http://localhost:$GP/ 2>/dev/null | tr -d '[:space:]')
[ "$A" = "v1" ] || { echo "FAIL: the Ingress path returned '$A', expected v1"; exit 1; }
[ "$B" = "v1" ] || { echo "FAIL: the Gateway path returned '$B', expected v1"; exit 1; }

# Host routing must be enforced, or the 200 above proves only that something
# answers on that port.
WRONG=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 -H 'Host: nope.example.com' http://localhost:$GP/ 2>/dev/null)
[ "$WRONG" != "200" ] || { echo "FAIL: an unmatched Host still gets 200 - the hostname is not being enforced"; exit 1; }

echo "PASS - the same app answers through the Ingress and the HTTPRoute, and unmatched hosts do not"
exit 0
