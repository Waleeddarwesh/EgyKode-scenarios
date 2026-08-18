# What validate cannot see

`validate` checks syntax and types against the provider schema. It has nothing
to say about code that is valid and wrong anyway.

## tflint

The `tags.tf` you reformatted in step 1 now passes both checks:

```
cd ~/infra
terraform fmt -check -recursive && echo "fmt: fine"
terraform validate && echo "validate: fine"
```{{exec}}

Formatted, valid. Ask a linter:

```
cd ~/infra
tflint
echo "tflint exit code: $?"
```{{exec}}

```
Warning: [Fixable] variable "common_tags" is declared but not used
```

Exit **2**. **Both earlier checks were right and the file is still wrong.**
`common_tags` is declared, has a sensible default, and nothing reads it — which
in a real module almost always means somebody renamed the input and left the old
one behind, and the value in `terraform.tfvars` has been going nowhere ever
since. Nobody notices, because the plan is clean.

That is the whole category `tflint` exists for: valid HCL that does not do what
the author thought. On a real AWS module `tflint --init` adds the provider
ruleset on top, which catches instance types that do not exist, deprecated
arguments, and missing required tags.

Delete it — the variable was never wired to anything:

```
cd ~/infra && rm tags.tf && tflint && echo "clean"
```{{exec}}

## The security scan

Neither check above has any opinion about whether the infrastructure is safe.
Write something plausible and dangerous:

```
mkdir -p ~/infra/examples && cd ~/infra/examples
cat > network.tf <<'TF'
resource "aws_security_group" "web" {
  name = "web"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_s3_bucket" "data" {
  bucket = "egykode-demo-data"
}
TF
terraform fmt -check -recursive && echo "fmt: fine"
```{{exec}}

Perfectly formatted. SSH open to the entire internet, and a bucket with no
encryption and no public-access block.

```
cd ~/infra
trivy config --severity HIGH,CRITICAL --exit-code 1 examples/
echo "trivy exit code: $?"
```{{exec}}

Exit `1`, with the findings named and a link for each. **`--exit-code 1` is what
makes it a gate rather than a report** — without it the job prints warnings, goes
green, and everyone stops reading it by the second week.

Notice what trivy did *not* need: no `terraform init`, no provider download, no
credentials. It parses the HCL. That is why a scan can run on a pull request
from a fork, in seconds, before anything else in the pipeline.

Now fix them:

```
cd ~/infra/examples
cat > network.tf <<'TF'
variable "office_cidr" {
  type        = string
  description = "The range permitted to reach SSH"
  default     = "203.0.113.0/24"
}

resource "aws_security_group" "web" {
  name        = "web"
  description = "Web tier"

  ingress {
    description = "SSH from the office only"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.office_cidr]
  }
}

resource "aws_s3_bucket" "data" {
  bucket = "egykode-demo-data"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "data" {
  bucket = aws_s3_bucket.data.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.data.arn
    }
  }
}

resource "aws_s3_bucket_public_access_block" "data" {
  bucket                  = aws_s3_bucket.data.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_kms_key" "data" {
  description             = "Customer managed key for the data bucket"
  enable_key_rotation     = true
  deletion_window_in_days = 30
}
TF
cd ~/infra
trivy config --severity HIGH,CRITICAL --exit-code 1 examples/ ; echo "trivy exit code: $?"
terraform fmt -check -recursive && echo "fmt: still fine"
```{{exec}}

Exit `0`. The change that would have failed the pipeline is the change that
never merges.

Note what it took to satisfy the encryption finding. `sse_algorithm = "aws:kms"`
on its own still fails — the rule asks for a **customer managed** key, so the
configuration needs an `aws_kms_key` of your own and a `kms_master_key_id`
pointing at it. Default AWS-managed encryption is encryption you cannot rotate
on your schedule, revoke, or audit access to.

**Done when:** `tflint` is clean and the scan of `examples/` exits 0.
