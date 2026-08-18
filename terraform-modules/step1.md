# The network module

A module is a directory. What makes it a module is that everything
environment-specific arrives through variables:

```
mkdir -p ~/platform/modules/network && cd ~/platform/modules/network

cat > variables.tf <<'TF'
variable "name" {
  description = "Name prefix for everything this module creates"
  type        = string
}

variable "cidr_block" {
  description = "CIDR for the VPC"
  type        = string
}

variable "azs" {
  description = "Availability zones to place subnets in"
  type        = list(string)
}
TF

cat > main.tf <<'TF'
resource "aws_vpc" "this" {
  cidr_block           = var.cidr_block
  enable_dns_hostnames = true

  tags = { Name = var.name }
}

resource "aws_subnet" "public" {
  for_each = { for i, az in var.azs : az => i }

  vpc_id            = aws_vpc.this.id
  availability_zone = each.key
  cidr_block        = cidrsubnet(var.cidr_block, 8, each.value)

  tags = { Name = "${var.name}-public-${each.key}" }
}
TF

cat > outputs.tf <<'TF'
output "vpc_id" {
  description = "Id of the VPC this module created"
  value       = aws_vpc.this.id
}

output "subnet_ids" {
  description = "Ids of the public subnets, in the order the AZs were given"
  value       = [for s in aws_subnet.public : s.id]
}
TF
ls
```{{exec}}

Two things in there are doing the real work.

**`cidrsubnet(var.cidr_block, 8, each.value)`** computes each subnet from the
VPC's CIDR instead of taking a list of them. Given `10.20.0.0/16` it produces
`10.20.0.0/24` and `10.20.1.0/24`; given `10.30.0.0/16` it produces
`10.30.0.0/24` and `10.30.1.0/24`. A module that took a list of subnet CIDRs
would need a different list for every caller, which is most of the way back to
copying the directory.

**`for_each` rather than `count`.** With `count`, subnets are addressed by
position — `aws_subnet.public[0]`, `[1]` — so removing the first AZ from the
list renumbers every subnet after it, and Terraform destroys and recreates them
all. With `for_each` they are addressed by AZ name, and removing one leaves the
others untouched. This is the single most common source of "why is it recreating
things I did not change".

## Use it

```
cd ~/platform
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

cat > main.tf <<'TF'
module "network" {
  source = "./modules/network"

  name       = "demo"
  cidr_block = "10.20.0.0/16"
  azs        = ["us-east-1a", "us-east-1b"]
}
TF
terraform init -input=false | grep -iE "initializing modules|successfully"
terraform apply -auto-approve -input=false | tail -3
```{{exec}}

```
awslocal ec2 describe-subnets \
  --query 'Subnets[].[SubnetId,CidrBlock,AvailabilityZone]' --output text
```{{exec}}

Two subnets, `10.20.0.0/24` and `10.20.1.0/24`, computed rather than written.

**Done when:** a VPC with CIDR `10.20.0.0/16` exists with two subnets in it.
