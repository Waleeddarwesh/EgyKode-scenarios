# Apply the plan that was reviewed

Everything so far ran without touching anything. This is where the pipeline
stops being free.

```
cd ~/infra
terraform plan -out=tfplan -input=false
```{{exec}}

Two things happened. Terraform printed a plan, and it wrote `tfplan` — a binary
file containing the exact set of changes, resolved against the state as it was a
moment ago.

Turn it into something a human can review:

```
cd ~/infra
terraform show -no-color tfplan > plan.txt
head -20 plan.txt
```{{exec}}

That file is what belongs in the pull request. **Reviewing the HCL is not
reviewing the change** — a two-line edit can produce a `-/+` that destroys and
recreates a database, and the only place that appears is the plan.

Apply exactly that:

```
cd ~/infra
terraform apply -input=false tfplan
cat out/app.conf
```{{exec}}

No prompt, no re-plan. It executed the file.

## Why this matters more than it looks

Plan again, then change the configuration *after* the plan is saved — exactly
what happens when someone merges to main while your pull request is waiting for
approval:

```
cd ~/infra
terraform plan -out=tfplan -var log_level=debug -input=false > /dev/null
sed -i 's/default = "info"/default = "trace"/' main.tf
grep default main.tf
terraform apply -input=false tfplan
cat out/app.conf
```{{exec}}

The configuration says `trace`. The applied result is `debug`.

**A saved plan cannot drift between approval and execution.** It is not a
suggestion that gets recalculated at apply time — it is the change, frozen. Had
this been `terraform apply` with a fresh plan, the thing that ran would have
been the thing nobody reviewed, and the difference between those two is the
entire argument for the artifact.

The corollary is worth stating too: a saved plan **goes stale**. Apply it after
the real world has moved and Terraform refuses, because the state it was
computed against no longer exists. That refusal is the feature.

Put the configuration back and re-apply so the state matches the source again:

```
cd ~/infra
sed -i 's/default = "trace"/default = "info"/' main.tf
terraform apply -auto-approve -input=false > /dev/null
cat out/app.conf
terraform plan -detailed-exitcode -input=false > /dev/null; echo "exit code: $?"
```{{exec}}

Exit `0` — no changes. Hold on to that number; the next step is built on it.

**Done when:** `out/app.conf` contains `log_level=info` and a plan reports no
changes.
