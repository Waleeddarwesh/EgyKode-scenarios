# Why the second apply does nothing

Run it again:

```
cd ~/infra
terraform apply -auto-approve -input=false | tail -3
```{{exec}}

```
No changes. Your infrastructure matches the configuration.
```

Nothing was created, nothing was skipped, and no command you ran said "only if
it does not already exist". **This is the property the whole tool is built on,
and it is worth being precise about how it happens**, because "Terraform is
idempotent" is a slogan people repeat without being able to say what it means.

Three things exist, and a plan compares them:

| | What it is |
| --- | --- |
| **Configuration** | What you wrote — the desired state |
| **State** | What Terraform believes it built, and the real ids |
| **Reality** | What is actually in the account |

`terraform plan` refreshes state from reality, compares it to the configuration,
and emits the difference. Second time round the difference is empty, so the plan
is empty, so the apply does nothing. It is a diff, not a script.

You can watch the refresh happen. Change reality behind Terraform's back:

```
cd ~/infra
INSTANCE=$(terraform output -raw instance_id)
awslocal ec2 create-tags --resources $INSTANCE --tags Key=Owner,Value=someone-else
terraform plan | grep -E '"?Owner"?|will be updated|No changes' | head -5
```{{exec}}

The plan noticed. The tag is in reality and not in the configuration, so
Terraform proposes removing it — **the configuration wins**, which is the point
of writing the infrastructure down. Nobody's console edit survives the next
apply, and that is a feature until the first time it deletes something somebody
needed, which is why the plan gets read.

```
cd ~/infra
terraform apply -auto-approve -input=false | tail -2
terraform plan -detailed-exitcode > /dev/null; echo "exit code: $?"
```{{exec}}

## The line in state that matters

State is JSON. The important part is the mapping from your name to the real id:

```
cd ~/infra
grep -B4 -A2 '"type": "aws_instance"' terraform.tfstate | head -14
```{{exec}}

Or read it directly:

```
cd ~/infra
terraform state list
terraform state show aws_instance.app | grep -E "^ *(id|instance_type|private_ip) "
```{{exec}}

`aws_instance.app` is your name for it. `i-...` is the account's. **State is the
only thing that connects the two**, and that is why losing it is not an
inconvenience: Terraform stops knowing that the instance in your account is the
one your configuration describes, and the next apply builds a second one.

Prove the id in state is the real one:

```
cd ~/infra
ID=$(terraform state show aws_instance.app | grep -E "^ *id " | head -1 | cut -d'"' -f2)
echo "state says: $ID"
awslocal ec2 describe-instances --instance-ids "$ID" \
  --query 'Reservations[].Instances[].[InstanceId,State.Name]' --output text
```{{exec}}

Same id, and AWS agrees it exists.

One more reason to keep state out of Git:

```
cd ~/infra
grep -c "secret\|password\|private" terraform.tfstate || true
wc -c terraform.tfstate
```{{exec}}

Every attribute of every resource is in that file in plain text — including the
ones a resource generates, like a database password or a private key. It is a
credential store that looks like a build artifact.

**Done when:** a plan reports no changes, and the id in state resolves to a real
instance.
