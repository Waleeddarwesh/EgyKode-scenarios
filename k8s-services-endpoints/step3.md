# Empty the endpoint list

"The Service exists but nothing reaches it" has two causes that look identical
from `kubectl get svc`. Produce both.

**One — the selector matches nothing:**

```
kubectl patch svc web -p '{"spec":{"selector":{"app":"wrong"}}}'
kubectl get endpoints web
kubectl exec client -- curl -s -o /dev/null -w 'while broken: %{http_code}\n' --max-time 5 http://web
```{{exec}}

The endpoint list is empty because no Pod carries `app=wrong`. Put it back:

```
kubectl patch svc web -p '{"spec":{"selector":{"app":"web"}}}'
kubectl get endpoints web
```{{exec}}

**Two — the Pods are not ready.** A readiness probe that fails removes a Pod
from the endpoint list without restarting it:

```
kubectl patch deployment web --type=json -p='[{"op":"add","path":"/spec/template/spec/containers/0/readinessProbe","value":{"httpGet":{"path":"/nonexistent","port":80},"periodSeconds":2,"failureThreshold":1}}]'
kubectl rollout status deploy/web --timeout=90s || true
kubectl get pods -l app=web
kubectl get endpoints web
```{{exec}}

**You should see** Pods `Running` but `0/1 READY`, and an empty endpoint list.
Running and ready are different things, and only readiness decides traffic.

Now fix it, and record both causes:

```
kubectl patch deployment web --type=json -p='[{"op":"remove","path":"/spec/template/spec/containers/0/readinessProbe"}]'
kubectl rollout status deploy/web --timeout=120s
printf 'cause 1: selector matched no pods\ncause 2: pods running but not ready\n' > /root/manifests/empty-endpoints.txt
kubectl get endpoints web
```{{exec}}
