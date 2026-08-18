#!/bin/bash
DIR=/root/infra
cd "$DIR" 2>/dev/null || { echo "FAIL: no $DIR"; exit 1; }

[ -x gate.sh ] || { echo "FAIL: no executable gate.sh"; exit 1; }

# All four checks must be in it. A gate missing the scan is the gate most teams
# actually have, and it passes everything this scenario was built to catch.
for CHECK in "fmt" "validate" "tflint" "trivy"; do
  grep -q "$CHECK" gate.sh || {
    echo "FAIL: gate.sh does not run $CHECK"; exit 1; }
done

# Without set -e the last command decides the exit code, so a failing scan
# followed by a passing plan reports success. That is not a gate.
grep -qE 'set -[a-z]*e' gate.sh || {
  echo "FAIL: gate.sh does not use set -e - a failing check would not stop it"; exit 1; }

# It has to actually pass, on the tree as it stands.
./gate.sh >/tmp/gate.out 2>&1 || {
  echo "FAIL: gate.sh does not pass:"
  tail -6 /tmp/gate.out
  exit 1; }

WF=$(ls .github/workflows/*.yml .github/workflows/*.yaml 2>/dev/null | head -1)
[ -n "$WF" ] || { echo "FAIL: no workflow file under .github/workflows/"; exit 1; }
grep -q "schedule" "$WF" || {
  echo "FAIL: the workflow has no schedule: block - nothing would ever check for drift"; exit 1; }

# And no drift right now, which is the state a passing scheduled run reports.
terraform plan -detailed-exitcode -input=false >/tmp/drift.out 2>&1
CODE=$?
[ "$CODE" -ne 2 ] || {
  echo "FAIL: terraform plan exits 2 - the resource has drifted from the configuration"
  echo "      terraform apply -auto-approve -input=false"
  exit 1; }
[ "$CODE" -eq 0 ] || { echo "FAIL: terraform plan errored (exit $CODE)"; tail -4 /tmp/drift.out; exit 1; }

echo "PASS - the gate runs all four checks and stops on failure, and there is no drift"
exit 0
