# The state file is gone

```
cd ~/recovery
awslocal s3api list-object-versions --bucket egykode-state-recovery \
  --prefix recovery/terraform.tfstate \
  --query 'Versions[].[VersionId,LastModified,Size]' --output text
```{{exec}}

Several versions, because every apply wrote a new one and the bucket keeps them.

Now lose it, the way it actually gets lost — somebody clearing up a bucket they
believed was scratch:

```
cd ~/recovery
awslocal s3api delete-object --bucket egykode-state-recovery --key recovery/terraform.tfstate
awslocal s3api list-objects-v2 --bucket egykode-state-recovery --prefix recovery/ \
  --query 'Contents[].Key' --output text
echo "--- what terraform thinks now:"
terraform plan -input=false 2>&1 | grep -E "will be created|Plan:|Error" | head -4
```{{exec}}

**Terraform wants to create everything.** It is not confused — its state is
empty, so as far as it knows none of this exists. Apply that and you get a
second VPC, a second subnet, and two sets of infrastructure with one
configuration.

This is the worst state to panic in, and the recovery is two commands.

## The delete marker

```
cd ~/recovery
awslocal s3api list-object-versions --bucket egykode-state-recovery \
  --prefix recovery/terraform.tfstate \
  --query 'DeleteMarkers[].[VersionId,IsLatest]' --output text
```{{exec}}

**The object was not erased.** Versioning turned the delete into a *delete
marker* — a tombstone placed on top of the versions, all of which are still
there. Removing the marker uncovers the most recent one.

```
cd ~/recovery
MARKER=$(awslocal s3api list-object-versions --bucket egykode-state-recovery \
  --prefix recovery/terraform.tfstate \
  --query 'DeleteMarkers[?IsLatest==`true`].VersionId' --output text)
echo "removing delete marker $MARKER"
awslocal s3api delete-object --bucket egykode-state-recovery \
  --key recovery/terraform.tfstate --version-id "$MARKER"
awslocal s3api list-objects-v2 --bucket egykode-state-recovery --prefix recovery/ \
  --query 'Contents[].[Key,Size]' --output text
```{{exec}}

The state file is back.

```
cd ~/recovery
terraform init -reconfigure -input=false > /dev/null
terraform state list
terraform plan -detailed-exitcode -input=false > /dev/null 2>&1; echo "plan exit code: $?"
```{{exec}}

Three resources, exit `0`. **The state matches reality again, and nothing in the
account was touched during any of it.**

## What made that recoverable

Versioning, enabled before it was needed. That is the whole of it.

Without it, `delete-object` removes the object and the recovery is rebuilding
state by importing every resource by hand — possible, slow, and error-prone in
proportion to how much you have.

Two more habits that belong with it:

- **`terraform state pull > backup.tfstate` before anything unusual.** A
  refactor, a provider upgrade, a bulk import. It costs a second
- **Never edit state by hand.** `terraform state` subcommands write a valid
  file; a text editor writes a file that parses and lies

**Done when:** the state file is back, `terraform state list` shows all three
resources, and the plan is quiet.
