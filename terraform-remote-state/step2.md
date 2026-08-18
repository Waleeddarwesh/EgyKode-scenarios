# Declare the backend and migrate

The bucket exists. Tell Terraform to use it:

```
cd ~/platform
cat > backend.tf <<'TF'
terraform {
  backend "s3" {
    bucket         = "egykode-tfstate"
    key            = "platform/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "egykode-tfstate-locks"
    encrypt        = true

    # LocalStack only.
    access_key                  = "test"
    secret_key                  = "test"
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    use_path_style              = true

    endpoints = {
      s3       = "http://localhost:4566"
      dynamodb = "http://localhost:4566"
    }
  }
}
TF
echo written
```{{exec}}

**`key` is the path inside the bucket, and it is how one bucket serves many
configurations.** `platform/terraform.tfstate`, `network/terraform.tfstate`,
`data/terraform.tfstate` — separate keys mean separate state files and separate
locks, so a network change and a platform change never wait on each other.

Two configurations that share a key share their state, which is a very quiet way
to have one of them delete the other's resources.

## Migrate

```
cd ~/platform
terraform init -migrate-state -force-copy -input=false | grep -iE "successfully|initialized"
```{{exec}}

`-force-copy` answers the "copy existing state to the new backend?" prompt with
yes. Without it the command waits for a human, which is what you want on a
laptop and what hangs a pipeline.

Now the question that matters — **did anything get destroyed and recreated?**

```
cd ~/platform
terraform state list
terraform plan -detailed-exitcode -input=false > /dev/null; echo "plan exit code: $?"
```{{exec}}

Five resources, still there, and exit code `0` — **no changes pending**.

That is the proof. A migration is a copy of the state file; it does not touch a
single real resource. Had Terraform lost track of them, the plan would want to
create five resources it thinks do not exist — and applying that against a
bucket that already exists is how a migration turns into an outage.

## Where the state actually is now

```
curl -s http://localhost:4566/egykode-tfstate/ | grep -o '<Key>[^<]*</Key>'
```{{exec}}

`platform/terraform.tfstate`, in the bucket.

And the local file?

```
cd ~/platform
ls -la terraform.tfstate terraform.tfstate.backup 2>/dev/null
```{{exec}}

Still on disk — and **no longer used**. Terraform leaves it behind as a safety
net after a migration. Prove it is stale by changing something and watching its
timestamp not move:

```
cd ~/platform
BEFORE=$(stat -c %Y terraform.tfstate)
cat >> state.tf <<'TF'

resource "aws_s3_bucket" "artifacts" {
  bucket = "egykode-artifacts"
}
TF
terraform apply -auto-approve -input=false | tail -2
AFTER=$(stat -c %Y terraform.tfstate)
[ "$BEFORE" = "$AFTER" ] && echo "local state NOT written - it is a leftover" || echo "local state was written"
```{{exec}}

Untouched. The apply went to S3.

Delete the leftovers, so nobody later mistakes them for the real thing:

```
cd ~/platform
rm -f terraform.tfstate terraform.tfstate.backup
terraform state list | wc -l
```{{exec}}

Six resources, and no local state file at all.

**Done when:** state is in S3, `terraform.tfstate` is gone from the working
directory, and a plan reports no changes.
