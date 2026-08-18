# Refactoring without destroying

Rename a resource. Just the label in your code — nothing about the real subnet
changes:

```
cd ~/recovery
sed -i 's|resource "aws_subnet" "app" {|resource "aws_subnet" "application" {|' main.tf
terraform plan | grep -E "will be destroyed|will be created|Plan:" | head -4
```{{exec}}

```
# aws_subnet.app will be destroyed
# aws_subnet.application will be created
Plan: 1 to add, 1 to destroy.
```

**Terraform is about to delete a subnet and build an identical one**, because a
resource's address is its identity in state. `aws_subnet.app` is gone from your
configuration, so it must be destroyed; `aws_subnet.application` is new, so it
must be created.

On a subnet that is a brief outage. On a database, an RDS instance or anything
holding data, it is the incident — and it arrives inside a change whose diff is
one word.

**This is why the plan gets read**, and why `will be destroyed` is the phrase to
search for before every apply.

## Tell Terraform it is the same resource

```
cd ~/recovery
cat >> main.tf <<'TF'

moved {
  from = aws_subnet.app
  to   = aws_subnet.application
}
TF
terraform plan | grep -E "have moved|will be destroyed|Plan:|No changes" | head -4
```{{exec}}

```
aws_subnet.app has moved to aws_subnet.application
No changes. Your infrastructure matches the configuration.
```

**A `moved` block is a rename in state, not an operation on infrastructure.**
Terraform reads it during planning, updates the address, and finds nothing left
to do.

```
cd ~/recovery
terraform apply -auto-approve -input=false | tail -2
terraform state list
```{{exec}}

The subnet is now `aws_subnet.application`, with the same real id it has had all
along:

```
cd ~/recovery
terraform state show aws_subnet.application | grep -E "^ *(id|cidr_block) " | head -2
```{{exec}}

## Why `moved` and not `state mv`

`terraform state mv aws_subnet.app aws_subnet.application` does the same thing
immediately, and it is the older way. The difference is who else it works for:

- **`state mv`** is a command *you* run, once, on your machine. A colleague who
  pulls your branch and applies gets the destroy-and-recreate, because their
  state was never moved
- **`moved`** is committed with the code. Everyone who applies it — including
  CI, including the person doing it next year — gets the rename

Keep the block after it has applied. It is harmless, and removing it re-arms the
destroy for anyone whose state has not caught up yet.

```
cd ~/recovery
terraform plan -detailed-exitcode > /dev/null 2>&1; echo "plan exit code: $?"
awslocal ec2 describe-subnets --filters Name=tag:Name,Values=recovery-app \
  --query 'Subnets[].[SubnetId,CidrBlock]' --output text
```{{exec}}

One subnet, the original one, with a different name in code and no downtime.

**Done when:** the subnet is addressed as `aws_subnet.application`, still has its
original id, and the plan is quiet.
