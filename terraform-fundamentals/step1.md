# A pinned provider, values in and out

```
mkdir -p ~/infra && cd ~/infra
cat > providers.tf <<'TF'
terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"      # 5.x, never 6.0
    }
  }
}

provider "aws" {
  region     = var.region
  access_key = "test"
  secret_key = "test"

  # LocalStack only. Against real AWS you delete this block entirely and let
  # the SDK find a role.
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  s3_use_path_style           = true

  endpoints {
    s3  = "http://localhost:4566"
    ec2 = "http://localhost:4566"
    iam = "http://localhost:4566"
    sts = "http://localhost:4566"
  }
}
TF
echo written
```{{exec}}

**`version = "~> 5.0"` is the line that makes this configuration reproducible.**
It permits 5.1 and 5.90 and refuses 6.0, because a major version is where
providers rename arguments and change defaults. Leave it out and the same
configuration, applied next month by somebody else, does something else.

`required_version` does the same for Terraform itself.

## Variables in

```
cd ~/infra
cat > variables.tf <<'TF'
variable "region" {
  description = "AWS region to build in"
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "Size of the application instance"
  type        = string
  default     = "t3.micro"
}

variable "bucket_name" {
  description = "Globally unique name for the asset bucket"
  type        = string
  default     = "egykode-assets"
}

variable "environment" {
  description = "Which environment this is"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging or prod."
  }
}
TF
echo written
```{{exec}}

Three things earn their place in every variable you will ever write:

- **`type`** — so `instance_type = 3` fails at plan time rather than at the API
- **`description`** — it is what `terraform-docs` publishes, and the only
  documentation anyone reads
- **`validation`** — the environment check above rejects a typo before it
  reaches AWS. Without it, `enviroment = "prod"` builds a fourth environment
  nobody planned

Watch the validation work. There are no resources yet, so this plan has
nothing to build and only the variables to check:

```
cd ~/infra
terraform init -input=false > /dev/null
terraform plan -var environment=production 2>&1 | grep -A3 "Invalid value"
```{{exec}}

`production` is not `prod`. Caught locally, in a second, with no credentials and
no API call.

And with a value it accepts:

```
cd ~/infra
terraform plan -var environment=prod 2>&1 | tail -3
```{{exec}}

`No changes.` — an empty configuration is a valid one. Terraform has compared
nothing to nothing and found them equal, which is exactly what it will do at the
end of the next step for a different reason.

**Done when:** the provider is pinned, the variables are typed, and
`environment=production` is rejected.

