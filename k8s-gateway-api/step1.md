# The same app, two ways in

An Ingress first — the resource you already know:

```
kubectl apply -f - <<'YAML'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: legacy
  namespace: routing
spec:
  ingressClassName: nginx
  rules:
    - host: legacy.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: v1
                port: { number: 80 }
YAML
sleep 8
kubectl -n routing get ingress
```{{exec}}

Watch the **ADDRESS** column. It is empty at first — the controller takes up to
about a minute and a half to publish it. Run the command again in a moment and
an address appears.

That column is how you tell an adopted Ingress from an orphaned one. **An
Ingress with a missing or wrong `ingressClassName` is accepted, listed cleanly,
and routes nothing** — and after a couple of minutes its ADDRESS is still blank
while `CLASS` reads `<none>`. It is the quietest failure in Kubernetes
networking, because every `kubectl get` looks reasonable.

```
INGRESS_PORT=$(kubectl -n ingress-nginx get svc ingress-nginx-controller -o jsonpath='{.spec.ports[0].nodePort}')
echo "ingress nodePort: $INGRESS_PORT"
curl -s -H 'Host: legacy.example.com' http://localhost:$INGRESS_PORT/
curl -s -o /dev/null -w 'wrong host: %{http_code}\n' -H 'Host: nope.example.com' http://localhost:$INGRESS_PORT/
```{{exec}}

`v1`, and a 404 for anything else. Host routing is real, not advisory.

## Now the same thing with Gateway API

It takes **two** resources, and that is the point:

```
kubectl apply -f - <<'YAML'
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: shop
  namespace: routing
spec:
  gatewayClassName: nginx
  listeners:
    - name: http
      protocol: HTTP
      port: 80
      hostname: "shop.example.com"
      allowedRoutes:
        namespaces: { from: Same }
---
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
YAML
sleep 12
kubectl -n routing get gateway,httproute
```{{exec}}

```
GATEWAY_PORT=$(kubectl -n nginx-gateway get svc nginx-gateway -o jsonpath='{.spec.ports[0].nodePort}')
echo "gateway nodePort: $GATEWAY_PORT"
curl -s -H 'Host: shop.example.com' http://localhost:$GATEWAY_PORT/
```{{exec}}

`v1` again — the same Deployment, reached through an entirely different data
path.

## Why two resources instead of one

| | Ingress | Gateway API |
| --- | --- | --- |
| Listener, port, TLS | In the same object as the routes | **`Gateway`** |
| Hostnames and paths | Same object | **`HTTPRoute`** |
| Who edits it | Everyone, together | Different teams, separately |

**An Ingress mixes infrastructure and application concerns in one file.** The
port and certificate belong to whoever runs the cluster; the paths belong to
whoever wrote the app. In Ingress they share a resource, so either both teams
have write access to both, or one team files tickets against the other.

Gateway API splits them, and step 3 makes that split do real work.

```
kubectl -n routing describe gateway shop | grep -A4 "Status:" | head -8
```{{exec}}

**Done when:** the app answers on `legacy.example.com` through the Ingress and on
`shop.example.com` through the Gateway.
