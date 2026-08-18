# Render and lint before the cluster sees anything

Build a small chart by hand. Four files, and every one of them earns its place:

```
mkdir -p myapp/templates && cd myapp

cat > Chart.yaml <<'YAML'
apiVersion: v2
name: myapp
description: The platform application
type: application
version: 0.1.0          # the chart's version
appVersion: "1.27"      # the application's version
YAML

cat > values.yaml <<'YAML'
replicaCount: 1
image:
  repository: nginx
  tag: "1.27-alpine"
  pullPolicy: IfNotPresent
config:
  LOG_LEVEL: "info"
  FEATURE_CHECKOUT: "false"
YAML
ls
```{{exec}}

**Two versions, two meanings.** `version` is the chart's own — bump it whenever
a template changes. `appVersion` is what the chart deploys. Conflating them is
why "we deployed 1.4.2" turns into an argument about which 1.4.2.

Names next. Defining them once is the difference between renaming a release and
hunting through templates:

```
cat > templates/_helpers.tpl <<'TPL'
{{- define "myapp.fullname" -}}
{{ .Release.Name }}-{{ .Chart.Name }}
{{- end -}}

{{- define "myapp.labels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "myapp.selectorLabels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
TPL

cat > templates/configmap.yaml <<'YAML'
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "myapp.fullname" . }}-config
  labels: {{- include "myapp.labels" . | nindent 4 }}
data:
  {{- toYaml .Values.config | nindent 2 }}
YAML

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
ls templates
```{{exec}}

Note `selectorLabels` is a **subset** of `labels`. A Deployment's selector is
immutable after creation, so anything that changes between releases — the app
version, most obviously — must stay out of it or the next upgrade fails
outright.

Now look at the YAML before anything is installed:

```
cd ~/myapp && helm template dev . | head -40
```{{exec}}

**`helm template` renders locally and talks to nothing.** This is the one you
run in CI on every pull request: it costs nothing, needs no cluster, and catches
the bracket you forgot.

```
helm lint .
```{{exec}}

`1 chart(s) linted, 0 chart(s) failed`.

## What lint will not catch

Set a replica count that is not a number:

```
cd ~/myapp
helm lint . --set replicaCount=two
helm template . --set replicaCount=two | grep -A1 "^spec:" | head -4
```{{exec}}

**Lint passes. The template renders happily.** It produced `replicas: two`,
which is not a valid Deployment, and neither command noticed — `lint` checks the
chart's structure and `template` does string substitution. Neither validates the
result against the Kubernetes API.

The obvious next move is Helm's own server-side dry run. Try it:

```
cd ~/myapp
helm install dev . -n dev --set replicaCount=two --dry-run=server > /tmp/dr.out 2>&1
echo "exit code: $?"
grep -ic error /tmp/dr.out
```{{exec}}

**Exit code 0, no errors.** It rendered the manifest and reported success on a
Deployment the cluster will not accept. `--dry-run=server` connects to the
cluster so template functions like `lookup` can work — it is not a validating
admission pass over the output.

This is the command that actually asks:

```
cd ~/myapp
helm template dev . --set replicaCount=two | kubectl apply --dry-run=server -n dev -f -
```{{exec}}

```
Error from server (BadRequest): Deployment in version "v1" cannot be handled
as a Deployment: json: cannot unmarshal string into Go struct field
DeploymentSpec.spec.replicas of type int32
```

**Four commands, and only the last one told the truth.** `lint` checks the
chart's structure, `template` does string substitution, `--dry-run=server`
renders with cluster access — none of them validate the result against the API.
Piping the rendered output through `kubectl apply --dry-run=server` does, and
that is the line worth having in CI.

**Done when:** the chart exists, `helm lint` passes, and `helm template` renders
a Deployment and a ConfigMap.
