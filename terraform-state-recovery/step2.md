# A resource Terraform does not know about

Somebody needed a security group during an incident and made one in the console.
It works, it is in use, and Terraform has never heard of it:

```
cd ~/recovery
VPC=$(terraform state show aws_vpc.main | grep -E "^ *id " | head -1 | cut -d'"' -f2)
SG=$(awslocal ec2 create-security-group --group-name emergency-access \
  --description "Made by hand during an incident" --vpc-id $VPC \
  --query 'GroupId' --output text)
echo "created by hand: $SG"
awslocal ec2 create-tags --resources $SG --tags Key=Name,Value=emergency-access
terraform plan -detailed-exitcode > /dev/null 2>&1; echo "plan exit code: $?"
```{{exec}}

Exit `0`. **Terraform reports no changes and is entirely correct** — nothing in
your configuration describes that security group, so there is nothing to
reconcile. A resource outside state is invisible, not wrong.

That invisibility is the problem. It will not be updated by a change to your
code, it will not be removed by `destroy`, and it will still be there — and
still billing, if it were something that bills — long after everyone who knew
about it has moved on.

## Describe it, then adopt it

Write the configuration first. It has to match what exists, or the first apply
after importing will change the real thing:

```
cd ~/recovery
cat >> main.tf <<'TF'

resource "aws_security_group" "emergency" {
  name        = "emergency-access"
  description = "Made by hand during an incident"
  vpc_id      = aws_vpc.main.id

  tags = { Name = "emergency-access" }
}
TF
terraform plan | grep -E "will be created|Plan:" | head -3
```{{exec}}

Terraform wants to **create** it, because it still does not know the resource
already exists. Applying that would fail on the duplicate name — or, for a
resource type that permits duplicates, quietly build a second one.

Import instead:

```
cd ~/recovery
SG=$(awslocal ec2 describe-security-groups --filters Name=group-name,Values=emergency-access \
  --query 'SecurityGroups[0].GroupId' --output text)
terraform import aws_security_group.emergency $SG
```{{exec}}

```
Import successful!
```

**`import` writes to state and touches nothing in the account.** It is the one
operation that adds a resource to Terraform's world without creating anything.

Now the check that matters:

```
cd ~/recovery
terraform plan -detailed-exitcode > /tmp/import.txt 2>&1; echo "plan exit code: $?"
grep -E "^  [~+-]|will be" /tmp/import.txt | head -5
```{{exec}}

Exit `0`. **An import is only finished when the plan is quiet.** Exit `2` here
would mean your configuration and the real resource disagree — and the next
apply would edit a resource somebody is relying on, which is a worse outcome
than leaving it unmanaged.

If they had disagreed, the fix is to change the configuration to match reality,
never to apply and let Terraform "correct" it.

```
cd ~/recovery
terraform state list
```{{exec}}

Three resources, one of which Terraform did not create.

**Done when:** the security group is in state and `terraform plan` reports no
changes.
