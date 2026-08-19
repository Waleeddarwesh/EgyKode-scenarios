# A ServiceMonitor Prometheus actually selects

Write the obvious one first. It will not work, and the two reasons why are the
most common scrape failures there are — both silent.

```
cat <<'YAML' | kubectl apply -f -
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: web
  namespace: shop
spec:
  selector:
    matchLabels:
      app: web
  endpoints:
    - port: "8080"
      interval: 15s
YAML
sleep 45
kubectl run q --rm -i --restart=Never --image=curlimages/curl:8.10.1 -n monitoring -- \
  curl -s "http://kps-kube-prometheus-stack-prometheus:9090/api/v1/query?query=up%7Bnamespace%3D%22shop%22%7D" \
  | grep -o '"result":\[[^]]*\]'
```{{exec}}

Still empty. The object was accepted — `kubectl` said `created`, the operator
logged nothing, and there is no event to look at. **This is the failure mode
worth internalising: a ServiceMonitor that matches nothing looks exactly like a
ServiceMonitor that works, until you go looking for the target.**

## Reason one: Prometheus does not select every ServiceMonitor

Ask what it *does* select:

```
kubectl get prometheus -n monitoring \
  -o jsonpath='{.items[0].spec.serviceMonitorSelector}{"\n"}'
kubectl get servicemonitor web -n shop --show-labels
```{{exec}}

`{"matchLabels":{"release":"kps"}}` against a ServiceMonitor with no labels at
all. The chart deliberately scopes Prometheus to its own release, so that
installing it does not hoover up every ServiceMonitor in the cluster. Your
object is outside that scope and is simply never read.

```
kubectl label servicemonitor web -n shop release=kps --overwrite
sleep 45
kubectl run q --rm -i --restart=Never --image=curlimages/curl:8.10.1 -n monitoring -- \
  curl -s "http://kps-kube-prometheus-stack-prometheus:9090/api/v1/query?query=up%7Bnamespace%3D%22shop%22%7D" \
  | grep -o '"result":\[[^]]*\]'
```{{exec}}

**Still empty.** One bug fixed, and nothing visible changed — which is exactly
why this step exists.

## Reason two: a ServiceMonitor names a port, not a number

```
kubectl get svc web -n shop -o jsonpath='name={.spec.ports[0].name} port={.spec.ports[0].port}{"\n"}'
```{{exec}}

The name is **empty**. `kubectl expose` creates an unnamed port, and
`endpoints[].port` in a ServiceMonitor is the *name* of a Service port — never
the number. `port: "8080"` was looking for a port called "8080", which does not
exist.

Fix both ends. The Service gets a named port; the ServiceMonitor refers to it
by that name:

```
cat <<'YAML' | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: web
  namespace: shop
  labels:
    app: web
spec:
  selector:
    app: web
  ports:
    - name: http
      port: 8080
      targetPort: 8080
---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: web
  namespace: shop
  labels:
    release: kps
spec:
  selector:
    matchLabels:
      app: web
  endpoints:
    - port: http
      interval: 15s
YAML
echo "waiting for the target to appear..."
for i in $(seq 1 24); do
  N=$(kubectl run q$i --rm -i --restart=Never --image=curlimages/curl:8.10.1 -n monitoring -- \
    curl -s "http://kps-kube-prometheus-stack-prometheus:9090/api/v1/query?query=up%7Bnamespace%3D%22shop%22%7D" 2>/dev/null \
    | grep -o '"value"' | wc -l)
  [ "$N" -gt 0 ] && { echo "up after about $((i*10))s"; break; }
  printf "."
  sleep 10
done
kubectl run q --rm -i --restart=Never --image=curlimages/curl:8.10.1 -n monitoring -- \
  curl -s "http://kps-kube-prometheus-stack-prometheus:9090/api/v1/query?query=up%7Bnamespace%3D%22shop%22%7D" \
  | tr ',' '\n' | grep -E '"pod"|"value"' | head
```{{exec}}

Both Pods, scraped, without one line of Prometheus configuration being edited —
which is the whole point of the operator. Add a third replica and it is scraped
too, because the Service selector matches it.

**Done when:** `up{namespace="shop"}` returns a result for each application Pod.
