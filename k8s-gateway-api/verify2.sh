#!/bin/bash
NS=routing

# Weights must be API fields, not annotations. An annotation-based canary is
# the thing this step exists to replace.
W=$(kubectl -n $NS get httproute app -o jsonpath='{.spec.rules[*].backendRefs[*].weight}' 2>/dev/null)
[ -n "$W" ] || { echo "FAIL: no weights on the HTTPRoute backendRefs"; exit 1; }
# Note: do not grep the annotations for "canary" here. kubectl stores the whole
# manifest in last-applied-configuration, and this route legitimately contains
# an x-canary header match - so that check fires on a correct answer.

BACKENDS=$(kubectl -n $NS get httproute app -o jsonpath='{.spec.rules[*].backendRefs[*].name}' 2>/dev/null | tr ' ' '\n' | sort -u | grep -c .)
[ "${BACKENDS:-0}" -ge 2 ] || { echo "FAIL: the route names ${BACKENDS:-0} distinct backend(s), expected 2"; exit 1; }

GP=$(kubectl -n nginx-gateway get svc nginx-gateway -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null)
[ -n "$GP" ] || { echo "FAIL: could not find the gateway node port"; exit 1; }

# Count the split. The band is wide on purpose: weighted round-robin converges
# over volume rather than enforcing a quota, so demanding exactly 80/20 would
# fail on a working system. It still rejects an even split or a single backend.
OUT=$(for i in $(seq 1 100); do curl -s --max-time 5 -H 'Host: shop.example.com' http://localhost:$GP/; done)
V1=$(echo "$OUT" | grep -c '^v1$')
V2=$(echo "$OUT" | grep -c '^v2$')
TOTAL=$((V1 + V2))
[ "$TOTAL" -ge 90 ] || { echo "FAIL: only $TOTAL of 100 requests were answered by v1 or v2"; exit 1; }
[ "$V2" -ge 3 ] || {
  echo "FAIL: v2 received $V2 of $TOTAL requests - the split is not reaching the second backend"; exit 1; }
[ "$V1" -ge 55 ] || {
  echo "FAIL: v1 received $V1 of $TOTAL requests - that is not an 80/20 split toward v1"; exit 1; }
[ "$V2" -le 45 ] || {
  echo "FAIL: v2 received $V2 of $TOTAL requests, far above the 20 percent it was given"; exit 1; }

# And the header match must pin the request, which chance cannot do five times.
PINNED=0
for i in 1 2 3 4 5; do
  R=$(curl -s --max-time 5 -H 'Host: shop.example.com' -H 'x-canary: always' http://localhost:$GP/ | tr -d '[:space:]')
  [ "$R" = "v2" ] && PINNED=$((PINNED + 1))
done
[ "$PINNED" -eq 5 ] || {
  echo "FAIL: the x-canary header reached v2 only $PINNED time(s) out of 5 - the header match is not pinning"
  exit 1; }

echo "PASS - split counted $V1/$V2 over $TOTAL requests, and x-canary pins to v2 every time"
exit 0
