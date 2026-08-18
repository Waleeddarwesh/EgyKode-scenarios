#!/bin/bash
DIR=/root/infra
[ -f "$DIR/main.tf" ] || { echo "FAIL: no $DIR/main.tf"; exit 1; }
cd "$DIR" || exit 1

[ -d .terraform ] || { echo "FAIL: the working directory is not initialised - terraform init -input=false"; exit 1; }

terraform fmt -check -recursive >/tmp/fmt.out 2>&1
FMT=$?
[ "$FMT" -eq 0 ] || {
  echo "FAIL: terraform fmt -check exits $FMT - these files need formatting:"
  cat /tmp/fmt.out
  echo "      terraform fmt -recursive"
  exit 1; }

terraform validate >/tmp/val.out 2>&1 || {
  echo "FAIL: terraform validate does not pass:"
  tail -5 /tmp/val.out
  exit 1; }

# Both checks pass on an empty directory too, so confirm there is something
# here for them to have checked.
RES=$(cat *.tf 2>/dev/null | grep -c '^resource')
[ "${RES:-0}" -ge 1 ] || { echo "FAIL: no resources declared - there is nothing for the gate to check"; exit 1; }

echo "PASS - formatted, valid, and there is a resource to validate"
exit 0
