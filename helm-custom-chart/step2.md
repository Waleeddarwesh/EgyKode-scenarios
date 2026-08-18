# One chart, two environments

Two values files. No template is edited, and neither file repeats anything the
chart already knows:

```
cd ~/myapp
cat > values-dev.yaml <<'YAML'
replicaCount: 1
config:
  LOG_LEVEL: "debug"
  FEATURE_CHECKOUT: "true"
YAML

cat > values-staging.yaml <<'YAML'
replicaCount: 3
config:
  LOG_LEVEL: "warn"
  FEATURE_CHECKOUT: "false"
YAML
ls values*
```{{exec}}

Install the same chart twice:

```
cd ~/myapp
helm install dev . -n dev -f values-dev.yaml --wait --timeout 180s
helm install staging . -n staging -f values-staging.yaml --wait --timeout 180s
helm list -A
```{{exec}}

```
kubectl get deploy,cm -n dev
kubectl get deploy,cm -n staging
```{{exec}}

One replica in `dev`, three in `staging`, each with its own ConfigMap, from one
set of templates that nobody edited.

Confirm the values really landed differently — inside the containers, not in the
files:

```
kubectl exec -n dev deploy/dev-myapp -- printenv LOG_LEVEL
kubectl exec -n staging deploy/staging-myapp -- printenv LOG_LEVEL
```{{exec}}

`debug` and `warn`.

## Why the names do not collide

Both releases rendered `{{ .Release.Name }}-{{ .Chart.Name }}`, giving
`dev-myapp` and `staging-myapp`. Had the chart hardcoded a name, the second
install into the same namespace would have failed — and installing into
different namespaces would have hidden the problem until the day somebody put
two releases in one namespace.

That is the whole reason the `fullname` helper exists, and why every chart you
will ever read starts with one.

## What differs, in one command

```
cd ~/myapp
diff <(helm get values dev -n dev) <(helm get values staging -n staging)
```{{exec}}

Six lines. That is the four-hundred-line diff between three manifest
directories, replaced by the part that was ever actually different.

**Done when:** both releases are installed, with one replica in `dev` and three
in `staging`, and different log levels inside the containers.
