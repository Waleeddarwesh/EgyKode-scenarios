# A weighted split, counted

Send a fifth of the traffic to `v2`. Note what is **not** in this manifest:

```
kubectl apply -f - <<'YAML'
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: app
  namespace: routing
spec:
  parentRefs:
    - name: shop
  hostnames: ["shop.example.com"]
  rules:
    - backendRefs:
        - name: v1
          port: 80
          weight: 80
        - name: v2
          port: 80
          weight: 20
YAML
sleep 10
kubectl -n routing get httproute app -o yaml | grep -A8 backendRefs
```{{exec}}

No annotations. `weight` is a **field in the API**, with a type, validated by the
API server, and documented by `kubectl explain httproute.spec.rules.backendRefs`.

The Ingress equivalent is three annotations that only ingress-nginx understands:

```text
nginx.ingress.kubernetes.io/canary: "true"
nginx.ingress.kubernetes.io/canary-weight: "20"
nginx.ingress.kubernetes.io/canary-by-header: "x-canary"
```

They are strings. Misspell one and nothing complains — the canary simply does
not happen, and you find out from a dashboard rather than from `kubectl apply`.

## Count it

```
GATEWAY_PORT=$(kubectl -n nginx-gateway get svc nginx-gateway -o jsonpath='{.spec.ports[0].nodePort}')
for i in $(seq 1 100); do
  curl -s -H 'Host: shop.example.com' http://localhost:$GATEWAY_PORT/
done | sort | uniq -c
```{{exec}}

```
     88 v1
     12 v2
```

Roughly four to one, and **not exactly** four to one. Weighted round-robin
distributes connections, it does not enforce a quota, so the ratio converges
over volume and wanders over a hundred requests. A canary check that demands
exactly 80/20 will fail on a working system.

## What a weight is not

**It is not a percentage.** Weights are relative: `80` and `20` behave
identically to `4` and `1`, or `800` and `200`. Add a third backend at `100` and
the first two do not keep their old shares.

**It is not sticky.** Each request is routed independently, so one user can see
`v1` then `v2` then `v1`. For a canary that is usually fine; for anything
holding session state it is not, and that is what `sessionPersistence` and
header-based matching are for.

Try the deliberate version — route by header instead of by chance:

```
kubectl apply -f - <<'YAML'
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: app
  namespace: routing
spec:
  parentRefs:
    - name: shop
  hostnames: ["shop.example.com"]
  rules:
    - matches:
        - headers:
            - name: x-canary
              value: "always"
      backendRefs:
        - name: v2
          port: 80
    - backendRefs:
        - name: v1
          port: 80
          weight: 80
        - name: v2
          port: 80
          weight: 20
YAML
sleep 10
GATEWAY_PORT=$(kubectl -n nginx-gateway get svc nginx-gateway -o jsonpath='{.spec.ports[0].nodePort}')
echo -n "with the header:    "; curl -s -H 'Host: shop.example.com' -H 'x-canary: always' http://localhost:$GATEWAY_PORT/
echo -n "and again:          "; curl -s -H 'Host: shop.example.com' -H 'x-canary: always' http://localhost:$GATEWAY_PORT/
echo -n "without the header: "; curl -s -H 'Host: shop.example.com' http://localhost:$GATEWAY_PORT/
```{{exec}}

The header always wins — **more specific rules are matched first**, which is
defined by the API rather than by the order you wrote them in. That is how a
team dogfoods its own canary while everyone else stays on the weighted split.

**Done when:** the weighted split sends traffic to both Services, and the
`x-canary` header pins a request to `v2`.
