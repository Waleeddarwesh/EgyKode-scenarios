# Allow exactly what is needed

The application is down. Now allow back the two things it actually does: talk to
the database, and resolve names.

**Both ends need a rule.** The default-deny selects every Pod in the namespace,
so the api needs permission to *send* and the database needs permission to
*receive*. Start with the database:

```
kubectl apply -f - <<'YAML'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: db-ingress
  namespace: platform
spec:
  podSelector:
    matchLabels: { app: postgres }
  policyTypes: ["Ingress"]

  ingress:
    - from:
        - podSelector:
            matchLabels: { app: api }
      ports:
        - protocol: TCP
          port: 5432
YAML
echo applied
```{{exec}}

Now the api side — and leave DNS out, the way almost everybody does the first
time:

```
kubectl apply -f - <<'YAML'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: api-egress
  namespace: platform
spec:
  podSelector:
    matchLabels: { app: api }
  policyTypes: ["Egress"]

  egress:
    - to:
        - podSelector:
            matchLabels: { app: postgres }
      ports:
        - protocol: TCP
          port: 5432
YAML
sleep 6
DB_IP=$(kubectl get pod -n platform -l app=postgres -o jsonpath='{.items[0].status.podIP}')
echo "by hostname:"
kubectl exec -n platform deploy/api -- wget -q -O- --timeout=5 http://db:5432 2>&1 | tail -1
echo "by IP ($DB_IP):"
kubectl exec -n platform deploy/api -- wget -q -O- --timeout=5 http://$DB_IP:5432 2>&1 | tail -1
```{{exec}}

```
by hostname:
command terminated with exit code 1
by IP (192.168.x.x):
db
```

**By IP it works. By name it does not.**

This is the most misleading failure in Kubernetes networking. The database is
reachable, the rule you wrote is correct as far as it goes, and every hostname
lookup is timing out — so the application hangs for five seconds and then fails,
rather than being refused. The symptom points at the database. The fault is DNS.

## Add the rule everybody forgets

```
kubectl apply -f - <<'YAML'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: api-egress
  namespace: platform
spec:
  podSelector:
    matchLabels: { app: api }
  policyTypes: ["Egress"]

  egress:
    # DNS first. Without it nothing resolves and every symptom misleads.
    - to:
        - namespaceSelector:
            matchLabels: { kubernetes.io/metadata.name: kube-system }
          podSelector:
            matchLabels: { k8s-app: kube-dns }
      ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53

    - to:
        - podSelector:
            matchLabels: { app: postgres }
      ports:
        - protocol: TCP
          port: 5432
YAML
sleep 6
kubectl exec -n platform deploy/api -- wget -q -O- --timeout=5 http://db:5432 2>&1 | tail -1
```{{exec}}

`db`. Resolved and connected.

Two details in that rule are worth more than they look:

**Both UDP and TCP on 53.** Resolvers use UDP and fall back to TCP for large
responses, so a UDP-only rule works until the day a response crosses 512 bytes —
and then fails intermittently, for one service, in a way nobody connects to a
NetworkPolicy written months earlier.

**`namespaceSelector` and `podSelector` in the same list item.** Together, one
`to:` entry means "Pods with this label, *inside* namespaces with that label".
Split them across two list items — a single extra `-` — and it means "any Pod in
kube-system, **or** any Pod labelled kube-dns anywhere". That is a far wider
grant, it is one character of YAML, and it looks nearly identical on the page.

## Confirm the block still holds

```
echo "api -> db (allowed):"
kubectl exec -n platform deploy/api -- wget -q -O- --timeout=5 http://db:5432 2>&1 | tail -1
echo "stranger -> db (must fail):"
kubectl exec -n platform stranger -- wget -q -O- --timeout=4 http://db:5432 2>&1 | tail -1
echo "stranger -> api (must fail):"
kubectl exec -n platform stranger -- wget -q -O- --timeout=4 http://api 2>&1 | tail -1
```{{exec}}

The application reaches its database. The stranger reaches neither, and no rule
anywhere mentions the stranger — it is denied because nothing allows it, which
is the only way NetworkPolicy can deny anything.

**Done when:** the api reaches the database by hostname, and the stranger
reaches nothing.
