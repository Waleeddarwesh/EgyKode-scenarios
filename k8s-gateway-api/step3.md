# Who owns the Gateway

The split you just made lives in the same namespace as the Gateway, which hides
the real difference. Move the Gateway to where it belongs — with the team that
runs the cluster:

NGINX Gateway Fabric manages **one Gateway per controller deployment**, so the
one from step 1 has to go before the shared one can take over. That is a
property of this controller, not of the API — others manage many:

```
kubectl -n routing delete gateway shop
kubectl -n routing delete httproute app
kubectl create namespace platform
kubectl label namespace routing team=shop --overwrite
kubectl label namespace default team=unapproved --overwrite

kubectl apply -f - <<'YAML'
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: shared
  namespace: platform
spec:
  gatewayClassName: nginx
  listeners:
    - name: http
      protocol: HTTP
      port: 80
      hostname: "*.example.com"
      allowedRoutes:
        namespaces:
          from: Selector
          selector:
            matchLabels:
              team: shop
YAML
sleep 15
kubectl -n platform get gateway shared
```{{exec}}

One listener, one hostname wildcard, and a **selector deciding which namespaces
may attach routes to it**. The platform team owns the port, the certificate and
that selector. They do not own anybody's paths.

## An application team attaches from its own namespace

```
kubectl apply -f - <<'YAML'
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: shop-routes
  namespace: routing
spec:
  parentRefs:
    - name: shared
      namespace: platform
  hostnames: ["shop.example.com"]
  rules:
    - backendRefs:
        - name: v1
          port: 80
YAML
sleep 10
kubectl -n routing get httproute shop-routes -o jsonpath='{.status.parents[0].conditions[?(@.type=="Accepted")].status}'; echo
```{{exec}}

`True`. The route in `routing` attached itself to a Gateway in `platform`,
across a namespace boundary, with **no edit to the Gateway** and no ticket.

## A namespace that was not invited

```
kubectl apply -f - <<'YAML'
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: sneaky
  namespace: default
spec:
  parentRefs:
    - name: shared
      namespace: platform
  hostnames: ["shop.example.com"]
  rules:
    - backendRefs:
        - name: kubernetes
          port: 443
YAML
sleep 10
kubectl -n default get httproute sneaky -o jsonpath='{.status.parents[0].conditions[?(@.type=="Accepted")].reason}'; echo
```{{exec}}

```
NotAllowedByListeners
```

**Rejected, with a reason, in status.** The `default` namespace does not carry
`team=shop`, so its route cannot attach — even though it asked for the same
hostname the legitimate team is using. Hostname squatting between teams is
something the API can refuse.

## The two things Ingress cannot express

- **An ownership boundary.** In Ingress, the listener and the routes are the
  same object, so anyone who may edit the routes may edit the port and the
  certificate. There is no way to grant one without the other
- **Typed, portable behaviour.** Weights, header matches, timeouts and traffic
  splitting are fields with schemas, validated on apply and identical on every
  conformant controller — not annotation strings that one controller reads and
  the next ignores

Both come from the same decision: **fewer, larger resources are easier to write
and impossible to delegate.**

```
kubectl get httproute -A
```{{exec}}

Routes in two namespaces, one Gateway, one team owning the entry point.

**Done when:** the Gateway lives in `platform`, the route from `routing` is
Accepted, and the route from `default` is refused with `NotAllowedByListeners`.
