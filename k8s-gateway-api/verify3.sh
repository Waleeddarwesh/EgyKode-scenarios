#!/bin/bash
kubectl -n platform get gateway shared >/dev/null 2>&1 || {
  echo "FAIL: no Gateway named shared in the platform namespace"; exit 1; }

# The boundary has to be a selector. from: All would accept every namespace and
# make the refusal below impossible.
FROM=$(kubectl -n platform get gateway shared -o jsonpath='{.spec.listeners[0].allowedRoutes.namespaces.from}' 2>/dev/null)
[ "$FROM" = "Selector" ] || {
  echo "FAIL: the listener allows routes from '${FROM:-unset}', not Selector"
  echo "      Without a selector there is no ownership boundary to demonstrate."
  exit 1; }

# A route from an invited namespace must attach across the boundary.
OK=$(kubectl -n routing get httproute shop-routes -o jsonpath='{.status.parents[0].conditions[?(@.type=="Accepted")].status}' 2>/dev/null)
[ "$OK" = "True" ] || {
  echo "FAIL: the route in routing is not Accepted by the shared Gateway (got '${OK:-none}')"; exit 1; }

# ...and one from an uninvited namespace must be refused, with a reason. This is
# the half that proves the selector is doing work rather than being decorative.
REASON=$(kubectl -n default get httproute sneaky -o jsonpath='{.status.parents[0].conditions[?(@.type=="Accepted")].reason}' 2>/dev/null)
[ -n "$REASON" ] || { echo "FAIL: no HTTPRoute named sneaky in default, or it has no status yet"; exit 1; }
[ "$REASON" = "NotAllowedByListeners" ] || {
  echo "FAIL: the route from default reports '$REASON', expected NotAllowedByListeners"
  echo "      If it was accepted, the namespace selector is not restricting anything."
  exit 1; }

# And the uninvited route must not actually serve traffic on the shared host.
GP=$(kubectl -n nginx-gateway get svc nginx-gateway -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null)
if [ -n "$GP" ]; then
  BODY=$(curl -s --max-time 8 -H 'Host: shop.example.com' http://localhost:$GP/ 2>/dev/null | tr -d '[:space:]')
  case "$BODY" in
    v1|v2) ;;
    *) echo "FAIL: shop.example.com returned '$BODY' - the legitimate route is not serving"; exit 1 ;;
  esac
fi

echo "PASS - the Gateway is owned by platform, routing attaches across the boundary, and default is refused"
exit 0
