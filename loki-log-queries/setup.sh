#!/bin/bash
# Runs in the background while the intro is read. Loki plus two workloads take
# a few minutes of image pulls; step 1 waits for them properly.

set -u

if ! command -v helm >/dev/null 2>&1; then
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 -o /tmp/get-helm-3 2>/dev/null
  bash /tmp/get-helm-3 >/dev/null 2>&1
fi

# The checks parse Loki's JSON, and a check that cannot parse its input fails
# for a reason that has nothing to do with the learner.
command -v jq >/dev/null 2>&1 || {
  apt-get update -qq >/dev/null 2>&1
  apt-get install -y -qq jq >/dev/null 2>&1
}

helm repo add grafana https://grafana.github.io/helm-charts >/dev/null 2>&1
helm repo update >/dev/null 2>&1

# ── Loki ────────────────────────────────────────────────────────────────────
# Single binary, filesystem storage, no persistent volume. The chart's default
# is a microservices split that wants object storage and a cache tier; none of
# that changes what LogQL does, and all of it changes how long this takes to
# start.
#
# The emptyDir is not optional. With persistence disabled the chart mounts
# nothing at /var/loki and the container's root filesystem is read-only, so
# Loki dies on startup with "mkdir /var/loki: read-only file system" — an
# error about storage that is really about a missing volume. A PVC would work
# too and would need a default StorageClass, which is not guaranteed here.
cat > /tmp/loki-values.yaml <<'YAML'
deploymentMode: SingleBinary
loki:
  auth_enabled: false
  commonConfig:
    replication_factor: 1
  storage:
    type: filesystem
  schemaConfig:
    configs:
      - from: "2024-04-01"
        store: tsdb
        object_store: filesystem
        schema: v13
        index:
          prefix: index_
          period: 24h
  limits_config:
    retention_period: 168h
singleBinary:
  replicas: 1
  persistence:
    enabled: false
  extraVolumes:
    - name: loki-data
      emptyDir: {}
  extraVolumeMounts:
    - name: loki-data
      mountPath: /var/loki
read:
  replicas: 0
write:
  replicas: 0
backend:
  replicas: 0
chunksCache:
  enabled: false
resultsCache:
  enabled: false
lokiCanary:
  enabled: false
test:
  enabled: false
gateway:
  enabled: false
YAML

helm upgrade --install loki grafana/loki --version 7.3.0 \
  -n monitoring --create-namespace -f /tmp/loki-values.yaml --timeout 10m >/dev/null 2>&1

# Reachable from this terminal without a port-forward to keep alive. Grafana
# would call the same API over the same HTTP; this way the query is visible
# instead of hidden inside a text box.
# Written out rather than `kubectl expose`, which does not take a StatefulSet
# and fails with a NotFound about the Service it did not create.
cat <<'YAML' | kubectl apply -f - >/dev/null 2>&1
apiVersion: v1
kind: Service
metadata:
  name: loki-api
  namespace: monitoring
spec:
  type: NodePort
  selector:
    app.kubernetes.io/name: loki
    app.kubernetes.io/instance: loki
    app.kubernetes.io/component: single-binary
  ports:
    - port: 3100
      targetPort: 3100
      nodePort: 31000
YAML

# ── The application that produces the logs ──────────────────────────────────
kubectl create namespace production >/dev/null 2>&1

kubectl -n production create deployment api --image=busybox:1.36 -- sh -c \
  'while true; do echo "{\"level\":\"info\",\"status\":200,\"msg\":\"GET /healthcheck\"}"; sleep 2; echo "ERROR db connection refused"; sleep 3; done' >/dev/null 2>&1

kubectl -n production create deployment web --image=busybox:1.36 -- sh -c \
  'while true; do echo "INFO serving request"; sleep 4; done' >/dev/null 2>&1

kubectl -n monitoring rollout status statefulset/loki --timeout=600s >/dev/null 2>&1
kubectl -n production rollout status deployment/api --timeout=300s >/dev/null 2>&1
kubectl -n production rollout status deployment/web --timeout=300s >/dev/null 2>&1

# Deliberately no promtail. Installing it before Loki answers is how this was
# first built, and it fails in a way worth seeing rather than hiding: the agent
# exhausts its retry budget, drops the batches, and afterwards discovers no new
# Pods — a stack that looks healthy and holds nothing. Step 1 installs it in
# the right order and says why.

echo done
