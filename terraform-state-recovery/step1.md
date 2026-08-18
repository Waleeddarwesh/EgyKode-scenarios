# Drift, and the two ways out

Build something to drift:

```
mkdir -p ~/recovery && cd ~/recovery
cat > providers.tf <<'TF'
terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }

  # State lives in a versioned bucket. Step 3 depends on that versioning, and
  # so does every real recovery.
  backend "s3" {
    bucket = "egykode-state-recovery"
    key    = "recovery/terraform.tfstate"
    region = "us-east-1"

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

provider "aws" {
  region     = "us-east-1"
  access_key = "test"
  secret_key = "test"

  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  s3_use_path_style           = true

  endpoints {
    s3       = "http://localhost:4566"
    ec2      = "http://localhost:4566"
    iam      = "http://localhost:4566"
    sts      = "http://localhost:4566"
    dynamodb = "http://localhost:4566"
  }
}
TF

cat > main.tf <<'TF'
resource "aws_vpc" "main" {
  cidr_block = "10.40.0.0/16"

  tags = {
    Name        = "recovery"
    Environment = "dev"
  }
}

resource "aws_subnet" "app" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.40.1.0/24"
  availability_zone = "us-east-1a"

  tags = { Name = "recovery-app" }
}
TF
terraform init -input=false > /dev/null
terraform apply -auto-approve -input=false | tail -2
```{{exec}}

## Somebody changes it by hand

```
cd ~/recovery
VPC=$(terraform state show aws_vpc.main | grep -E "^ *id " | head -1 | cut -d'"' -f2)
awslocal ec2 create-tags --resources $VPC --tags Key=Owner,Value=ops-oncall Key=Environment,Value=production
awslocal ec2 describe-tags --filters Name=resource-id,Values=$VPC \
  --query 'Tags[].[Key,Value]' --output text
```{{exec}}

A tag added, and an existing one changed from `dev` to `production` — the kind of
thing that happens during an incident and is never mentioned afterwards.

```
cd ~/recovery
terraform plan -detailed-exitcode > /tmp/drift.txt 2>&1; echo "exit code: $?"
grep -E "^  [~+-]|will be updated" /tmp/drift.txt | head -8
```{{exec}}

Exit `2`. **Terraform refreshed state from reality, compared it to your
configuration, and found a difference.** It wants to remove `Owner` and set
`Environment` back to `dev`.

## Two ways out, and they mean opposite things

**Reassert the configuration.** The code is the truth; the console change was a
mistake:

```
cd ~/recovery
terraform apply -auto-approve -input=false | tail -2
terraform plan -detailed-exitcode > /dev/null 2>&1; echo "exit code: $?"
awslocal ec2 describe-tags --filters Name=resource-id,Values=$(terraform state show aws_vpc.main | grep -E "^ *id " | head -1 | cut -d'"' -f2) \
  --query 'Tags[].[Key,Value]' --output text
```{{exec}}

The hand-made change is gone. That is the right answer when the console edit was
unauthorised — and the wrong one when it was an emergency fix somebody needed.

**Or adopt the change into code.** The console change was correct and the
configuration is out of date:

```
cd ~/recovery
awslocal ec2 create-tags --resources $(terraform state show aws_vpc.main | grep -E "^ *id " | head -1 | cut -d'"' -f2) --tags Key=Owner,Value=ops-oncall
sed -i 's|    Environment = "dev"|    Environment = "dev"\n    Owner       = "ops-oncall"|' main.tf
terraform plan -detailed-exitcode > /dev/null 2>&1; echo "exit code: $?"
grep -A4 "tags" main.tf | head -6
```{{exec}}

Exit `0`. Reality and configuration agree again — this time by changing the
configuration rather than the resource.

**Both are one command. Choosing between them is the entire skill**, and it is
not a Terraform question: it is asking whether the person who made the change
knew something you do not.

Nothing in either path destroyed anything. Confirm:

```
cd ~/recovery
terraform state list
```{{exec}}

**Done when:** the plan reports no changes, and both resources are still in
state.
