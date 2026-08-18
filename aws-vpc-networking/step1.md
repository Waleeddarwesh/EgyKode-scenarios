# Four subnets, two availability zones

```
mkdir -p ~/network && cd ~/network
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

  endpoints {
    ec2 = "http://localhost:4566"
    sts = "http://localhost:4566"
    iam = "http://localhost:4566"
    s3  = "http://localhost:4566"
  }
}
TF

cat > variables.tf <<'TF'
variable "vpc_cidr" {
  description = "Address space for the whole VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "azs" {
  description = "Availability zones to spread across"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}
TF

cat > network.tf <<'TF'
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = { Name = "egykode" }
}

resource "aws_subnet" "public" {
  for_each = { for i, az in var.azs : az => i }

  vpc_id                  = aws_vpc.main.id
  availability_zone       = each.key
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, each.value)
  map_public_ip_on_launch = true

  tags = {
    Name = "egykode-public-${each.key}"
    Tier = "public"
  }
}

resource "aws_subnet" "private" {
  for_each = { for i, az in var.azs : az => i }

  vpc_id            = aws_vpc.main.id
  availability_zone = each.key
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, each.value + 10)

  tags = {
    Name = "egykode-private-${each.key}"
    Tier = "private"
  }
}
TF
terraform init -input=false > /dev/null
terraform apply -auto-approve -input=false | tail -3
```{{exec}}

```
awslocal ec2 describe-subnets \
  --filters Name=tag:Name,Values=egykode-* \
  --query 'Subnets[].[Tags[?Key==`Name`].Value|[0],CidrBlock,AvailabilityZone]' \
  --output text | sort
```{{exec}}

`10.0.0.0/24` and `10.0.1.0/24` public, `10.0.10.0/24` and `10.0.11.0/24`
private, one pair in each zone.

## Three decisions worth naming

**The offset of 10.** `cidrsubnet(var.vpc_cidr, 8, each.value + 10)` puts private
subnets at `.10` and `.11` rather than `.2` and `.3`. That gap is deliberate:
adding a third availability zone later inserts `10.0.2.0/24` as public without
renumbering anything private. Pack them adjacently and the first expansion
forces a redesign.

**Two availability zones, not one.** An AZ is a failure domain — a separate
building with separate power. Everything you place later, from a load balancer
to a database, needs subnets in at least two of them, and the AZ is fixed at
creation. A single-AZ VPC has to be rebuilt to become highly available.

**`map_public_ip_on_launch` on public subnets only.** It gives instances a
public address automatically. Setting it on a private subnet is one of the
quieter ways to expose something you thought was internal, and it is a subnet
property rather than an instance one, so nothing at launch time warns you.

**The `Tier` tags are documentation.** They record what you intended. They do
not make anything public or private — that is decided two steps from now, and
`describe-subnets` output above contains no notion of public or private at all.

**Done when:** one VPC contains four subnets, two per availability zone.
