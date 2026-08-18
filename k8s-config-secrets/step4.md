# Make a config change reach the Pods

Change the log level:

```
kubectl patch configmap app-config -n platform --type merge -p '{"data":{"LOG_LEVEL":"debug"}}'
kubectl get configmap app-config -n platform -o jsonpath='{.data.LOG_LEVEL}'; echo
```{{exec}}

The ConfigMap says `debug`. Now ask the running process:

```
kubectl exec -n platform deploy/api -- printenv LOG_LEVEL
```{{exec}}

Still `info`. **Environment variables are read once, when the process starts.**
Nothing is broken and nothing will fix itself — the Pods are running with the
values that existed when they booted.

There are two ways out, and they behave differently:

- **`envFrom`** — a new value needs a **new process**. Restart the Pods.
- **A ConfigMap mounted as a volume** — the kubelet refreshes the file within
  about a minute, but the application only benefits if it re-reads the file.

You used `envFrom`, so restart:

```
kubectl rollout restart deployment/api -n platform
kubectl rollout status deployment/api -n platform --timeout=180s
kubectl exec -n platform deploy/api -- printenv LOG_LEVEL
```{{exec}}

`debug`. The change reached the Pods because you replaced them.

This is worth remembering precisely, because "I changed the ConfigMap and
nothing happened" is one of the most common Kubernetes support questions there
is — and the answer is that nothing was supposed to happen.

**Done when:** the ConfigMap says `debug` and so does the running container.
