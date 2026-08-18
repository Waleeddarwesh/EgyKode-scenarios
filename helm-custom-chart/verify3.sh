#!/bin/bash
NS=dev

# The annotation must be on the Pod template of the deployed release, not
# merely present somewhere in the chart source.
ANN=$(kubectl get deployment dev-myapp -n $NS -o jsonpath='{.spec.template.metadata.annotations.checksum/config}' 2>/dev/null)
[ -n "$ANN" ] || {
  echo "FAIL: the Pod template has no checksum/config annotation"
  echo "      Add it to templates/deployment.yaml and run helm upgrade."
  exit 1; }

CM=$(kubectl get configmap dev-myapp-config -n $NS -o jsonpath='{.data.LOG_LEVEL}' 2>/dev/null)
[ -n "$CM" ] || { echo "FAIL: the dev-myapp-config ConfigMap has no LOG_LEVEL"; exit 1; }

kubectl rollout status deployment/dev-myapp -n $NS --timeout=90s >/dev/null 2>&1

# The check that means something: the value in the running process, compared
# with the value in the ConfigMap. This is exactly the state that was wrong
# before the annotation existed, and the annotation is the only reason it is
# right now.
RUNNING=$(kubectl exec -n $NS deploy/dev-myapp -- printenv LOG_LEVEL 2>/dev/null)
[ "$RUNNING" = "$CM" ] || {
  echo "FAIL: the ConfigMap says '$CM' but the running container says '$RUNNING'"
  echo "      The config changed without a rollout - that is the failure this step fixes."
  exit 1; }

# And the staging release must still be intact, since the chart is shared.
helm status staging -n staging >/dev/null 2>&1 || {
  echo "FAIL: the staging release is gone - the chart edit should not have disturbed it"; exit 1; }

echo "PASS - the config change rolled the Pods, and the container matches the ConfigMap ($CM)"
exit 0
