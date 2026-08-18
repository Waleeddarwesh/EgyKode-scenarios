#!/bin/bash
DIR=/root/infra
cd "$DIR" 2>/dev/null || { echo "FAIL: no $DIR"; exit 1; }

[ -f terraform.tfstate ] || { echo "FAIL: no state file - nothing has been applied"; exit 1; }

# The resource must actually exist, not merely be recorded.
[ -f out/app.conf ] || { echo "FAIL: out/app.conf does not exist - the apply did not run"; exit 1; }
CONTENT=$(cat out/app.conf)
echo "$CONTENT" | grep -q "log_level=info" || {
  echo "FAIL: out/app.conf contains '$CONTENT', expected log_level=info"
  echo "      Put the default back to \"info\" and re-apply."
  exit 1; }

# A saved plan has to have been produced at some point, since that is the habit
# the step exists to build.
[ -f tfplan ] || { echo "FAIL: no saved plan file - terraform plan -out=tfplan"; exit 1; }

# State and configuration must agree, which is what makes the drift check in
# the next step meaningful rather than a leftover.
terraform plan -detailed-exitcode -input=false >/tmp/plan.out 2>&1
CODE=$?
[ "$CODE" -eq 0 ] || {
  echo "FAIL: terraform plan reports exit code $CODE - the state and configuration do not agree yet"
  grep -E "^  # |will be" /tmp/plan.out | head -5
  exit 1; }

echo "PASS - the plan was saved and applied, and state matches the configuration"
exit 0
