# The bucket that cannot create itself

Point Terraform at LocalStack. Everything here is exactly what you would write
for real AWS except the `endpoints` block and the fake credentials:

```
mkdir -p ~/platform && cd ~/platform
cat > providers.tf <<'TF'
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region     = "us-east-1"
  access_key = "test"
  secret_key = "test"

  # LocalStack only. On real AWS you delete this block and use a role.
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  s3_use_path_style           = true

  endpoints {
    s3       = "http://localhost:4566"
    dynamodb = "http://localhost:4566"
  }
}
TF
terraform init -input=false | tail -3
```{{exec}}

That download is the AWS provider — a hundred-odd megabytes, once.

Now the state bucket. Four separate resources, because AWS split them apart:

```
cd ~/platform
cat > state.tf <<'TF'
resource "aws_s3_bucket" "state" {
  bucket = "egykode-tfstate"
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_dynamodb_table" "locks" {
  name         = "egykode-tfstate-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}
TF
terraform apply -auto-approve -input=false | tail -3
```{{exec}}

Each setting is there for a specific failure:

- **Versioning** — state is the only record of what exists. A bad apply that
  writes a truncated state file is recoverable only if the previous version is
  still there. This is the one you will be glad of
- **Encryption** — state contains every value Terraform touched, including
  database passwords and generated keys, in plain text
- **Public access block** — a world-readable state file is a map of your entire
  infrastructure, with the credentials
- **`LockID` as the hash key** — that exact name. The backend writes an item
  keyed on it, and a different key means locking silently does nothing

## The chicken and the egg

```
cd ~/platform
ls terraform.tfstate
terraform state list
```{{exec}}

The bucket that will hold your state is itself managed by Terraform, and its
state is currently **local**. It cannot be otherwise: the backend has to exist
before anything can be stored in it.

This is why the state bucket is normally a small, separate configuration —
applied once, rarely touched, and often committed with its local state file, or
created by a one-line CLI command outside Terraform entirely. Trying to be
clever here produces a configuration that cannot be applied from scratch.

**Done when:** the bucket exists with versioning, encryption and public access
blocked, and the lock table exists with `LockID` as its hash key.
