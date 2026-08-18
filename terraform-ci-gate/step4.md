# One gate, and a drift check

Four checks, one script, cheapest first, and every failure fatal:

```
cd ~/infra
cat > gate.sh <<'SH'
#!/bin/bash
set -euo pipefail

echo "==> fmt"
terraform fmt -check -recursive

echo "==> init (no backend, no credentials)"
terraform init -backend=false -input=false > /dev/null

echo "==> validate"
terraform validate

echo "==> tflint"
tflint

echo "==> security scan"
trivy config --severity HIGH,CRITICAL --exit-code 1 .

echo "==> plan"
terraform plan -out=tfplan -input=false > /dev/null
terraform show -no-color tfplan > plan.txt

echo "ALL CHECKS PASSED - plan.txt is ready for review"
SH
chmod +x gate.sh
./gate.sh
```{{exec}}

`set -e` is what makes it a gate. Without it every check runs, the last one
decides the exit code, and a failing scan followed by a passing plan reports
success.

Prove it fails on a bad change:

```
cd ~/infra
echo 'variable "unused_thing" { type = string }' >> main.tf
./gate.sh ; echo "gate exit code: $?"
```{{exec}}

It stops at `tflint` and never reaches the plan — which is the point of the
ordering. The expensive steps only run on changes that have earned them.

```
cd ~/infra
sed -i '/unused_thing/d' main.tf
terraform fmt -recursive > /dev/null
./gate.sh | tail -2
```{{exec}}

## The same gate, in CI

```
cd ~/infra
mkdir -p .github/workflows
cat > .github/workflows/terraform.yml <<'YML'
name: terraform
on:
  pull_request:
    paths: ["infra/**"]
  schedule:
    - cron: "0 6 * * 1"     # weekly drift check

permissions:
  contents: read
  id-token: write           # OIDC, not a stored access key

jobs:
  gate:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: infra
    steps:
      - uses: actions/checkout@v4
      - uses: hashicorp/setup-terraform@v3
      - run: terraform fmt -check -recursive
      - run: terraform init -backend=false -input=false
      - run: terraform validate
      - uses: terraform-linters/setup-tflint@v4
      - run: tflint
      - uses: aquasecurity/trivy-action@master
        with:
          scan-type: config
          severity: HIGH,CRITICAL
          exit-code: "1"
      - run: terraform plan -out=tfplan -input=false
      - uses: actions/upload-artifact@v4
        with:
          name: tfplan
          path: infra/tfplan
YML
cat .github/workflows/terraform.yml | head -12
```{{exec}}

Two things in there are worth naming. **`id-token: write` with no secrets** —
the job assumes an AWS role through OIDC rather than carrying a long-lived
access key that leaks the moment somebody prints the environment. And the plan
is **uploaded as an artifact**, so the apply job downloads and applies that
file rather than planning again.

## Drift

The `schedule:` block is not decoration. Change the managed resource behind
Terraform's back, the way a person does at two in the morning during an
incident:

```
cd ~/infra
echo "log_level=tampered_by_hand" > out/app.conf
terraform plan -detailed-exitcode -input=false > /dev/null
echo "exit code: $?"
```{{exec}}

**Exit `2`.** `-detailed-exitcode` gives three answers where a normal plan gives
two:

| Code | Means |
| --- | --- |
| `0` | No changes. Reality matches the configuration |
| `1` | The plan itself errored |
| `2` | **Changes are pending** — reality has drifted |

That is the whole drift check: a weekly job running `plan -detailed-exitcode`,
failing on `2`, and telling you on a Monday morning rather than during the next
incident — when the emergency edit somebody made and forgot gets silently
reverted by an unrelated apply.

```
cd ~/infra
terraform apply -auto-approve -input=false > /dev/null
cat out/app.conf
terraform plan -detailed-exitcode -input=false > /dev/null; echo "exit code: $?"
```{{exec}}

Back to `0`. Terraform reasserted the configuration and the hand edit is gone —
which is exactly what would have happened during that unrelated apply, without
anyone deciding it should.

**Done when:** `gate.sh` runs all four checks and exits 0, the workflow file
exists, and a plan reports no drift.
