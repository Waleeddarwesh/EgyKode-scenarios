# Reach it by name

A Service gets a DNS record. Another Pod can reach it without knowing a single
address.

```
kubectl run client --image=curlimages/curl:8.10.1 --restart=Never -- sleep 3600
kubectl wait --for=condition=Ready pod/client --timeout=120s
kubectl exec client -- curl -s -o /dev/null -w 'short name: %{http_code}\n' http://web
kubectl exec client -- curl -s -o /dev/null -w 'fqdn:       %{http_code}\n' http://web.default.svc.cluster.local
```{{exec}}

Both work. The short name resolves because the Pod's resolver is configured
with a search domain:

```
kubectl exec client -- cat /etc/resolv.conf
```{{exec}}

**You should see** `search default.svc.cluster.local svc.cluster.local ...`.
That is why `web` alone is enough inside the same namespace, and why a Service
in *another* namespace needs `web.other-namespace`.

Record the proof:

```
kubectl exec client -- curl -s -o /dev/null -w '%{http_code}' http://web > /root/manifests/dns-check.txt
cat /root/manifests/dns-check.txt
```{{exec}}
