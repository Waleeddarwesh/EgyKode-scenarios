# The annotation that turns a config change into a rollout

Change a value in `dev` and watch what the cluster does about it:

```
cd ~/myapp
kubectl get pods -n dev
sed -i 's/LOG_LEVEL: "debug"/LOG_LEVEL: "trace"/' values-dev.yaml
helm upgrade dev . -n dev -f values-dev.yaml --wait --timeout 180s > /dev/null
echo "--- ConfigMap now says:"
kubectl get cm dev-myapp-config -n dev -o jsonpath='{.data.LOG_LEVEL}'; echo
echo "--- the running container says:"
kubectl exec -n dev deploy/dev-myapp -- printenv LOG_LEVEL
echo "--- and the Pods:"
kubectl get pods -n dev
```{{exec}}

The ConfigMap says `trace`. The container says `debug`. **The Pod was never
restarted** — same name, same age as before the upgrade.

Helm did exactly what it was asked: it updated the ConfigMap. The Deployment's
Pod template did not change, so there was nothing to roll, and environment
variables are read once when a process starts.

This is a deploy that reports success and changes nothing. The new value will
take effect at some unpredictable future moment — the next unrelated upgrade, a
node drain, an OOM kill — which is worse than not deploying at all, because by
then nobody will connect the two.

## Make the Pod template depend on the config

Hash the rendered ConfigMap into the Pod template's annotations:

```
cd ~/myapp
cat > templates/deployment.yaml <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "myapp.fullname" . }}
  labels: {{- include "myapp.labels" . | nindent 4 }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels: {{- include "myapp.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      annotations:
        checksum/config: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}
      labels: {{- include "myapp.selectorLabels" . | nindent 8 }}
    spec:
      containers:
        - name: {{ .Chart.Name }}
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          envFrom:
            - configMapRef:
                name: {{ include "myapp.fullname" . }}-config
YAML
helm template dev . -f values-dev.yaml | grep -A2 "annotations:"
```{{exec}}

The annotation is a hash of the rendered `configmap.yaml`. Change any value in
it and the hash changes; the hash lives in the Pod template; a changed Pod
template **is** a rollout. Nothing watches anything — it is a plain
consequence of how Deployments work.

Now do the same edit again:

```
cd ~/myapp
sed -i 's/LOG_LEVEL: "trace"/LOG_LEVEL: "info"/' values-dev.yaml
helm upgrade dev . -n dev -f values-dev.yaml --wait --timeout 180s > /dev/null
kubectl get pods -n dev
echo "--- the running container says:"
kubectl exec -n dev deploy/dev-myapp -- printenv LOG_LEVEL
```{{exec}}

A new Pod, seconds old, and the container reports `info`. The config change and
the rollout are now the same event.

## The one that catches people later

If you add an HPA to this chart, wrap the replica count:

```yaml
  {{- if not .Values.autoscaling.enabled }}
  replicas: {{ .Values.replicaCount }}
  {{- end }}
```

Leaving `replicas` in the manifest while an HPA is also managing it means every
`helm upgrade` resets the count to the chart's value, and the HPA scales it back
up a moment later. The two fight quietly, forever, and the graph looks like a
saw.

**Done when:** the Pod template carries a `checksum/config` annotation, and the
value inside the running container matches the ConfigMap.
