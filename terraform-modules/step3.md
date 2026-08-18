# Call it twice

A module you can only call once is a directory with extra steps. Add a second
environment — four lines, no new files:

```
cd ~/platform
cat > main.tf <<'TF'
module "network" {
  source = "./modules/network"

  name       = "demo"
  cidr_block = "10.20.0.0/16"
  azs        = ["us-east-1a", "us-east-1b"]
}

module "network_staging" {
  source = "./modules/network"

  name       = "staging"
  cidr_block = "10.30.0.0/16"
  azs        = ["us-east-1a", "us-east-1b"]
}

module "app" {
  source = "./modules/compute"

  name      = "demo-app"
  subnet_id = module.network.subnet_ids[0]
}

module "app_staging" {
  source = "./modules/compute"

  name      = "staging-app"
  subnet_id = module.network_staging.subnet_ids[0]
}
TF

cat > outputs.tf <<'TF'
output "network_vpc" {
  value = module.network.vpc_id
}

output "staging_vpc" {
  value = module.network_staging.vpc_id
}

output "app_instance" {
  value = module.app.instance_id
}

output "staging_instance" {
  value = module.app_staging.instance_id
}
TF
terraform init -input=false > /dev/null
terraform apply -auto-approve -input=false | tail -3
terraform output
```{{exec}}

Two VPCs, four subnets, two instances — from the same two modules, which were
not edited.

## Confirm they are actually independent

```
awslocal ec2 describe-vpcs \
  --query 'Vpcs[?CidrBlock!=`172.31.0.0/16`].[VpcId,CidrBlock,Tags[?Key==`Name`].Value|[0]]' \
  --output text
```{{exec}}

```
cd ~/platform
for V in $(terraform output -raw network_vpc) $(terraform output -raw staging_vpc); do
  echo "== $V"
  awslocal ec2 describe-subnets --filters Name=vpc-id,Values=$V \
    --query 'Subnets[].[SubnetId,CidrBlock]' --output text
done
```{{exec}}

`10.20.0.0/24` and `10.20.1.0/24` in one, `10.30.0.0/24` and `10.30.1.0/24` in
the other. **The module computed each set from the CIDR it was given** — this is
what `cidrsubnet` bought, and a module that accepted a list of subnet CIDRs
would have needed a second list here.

And each instance is in its own network:

```
cd ~/platform
for I in $(terraform output -raw app_instance) $(terraform output -raw staging_instance); do
  awslocal ec2 describe-instances --instance-ids $I \
    --query 'Reservations[].Instances[].[InstanceId,PrivateIpAddress,SubnetId]' --output text
done
```{{exec}}

One address in `10.20.x`, one in `10.30.x`. Independent networks, no shared
resources, nothing hardcoded.

## Where state keeps them apart

```
cd ~/platform
terraform state list | sed 's/\..*//' | sort | uniq -c
```{{exec}}

Every resource is addressed by the module instance that created it —
`module.network.aws_vpc.this` and `module.network_staging.aws_vpc.this` are two
different addresses for the same line of module code. **That address is why the
two calls cannot collide**, and it is also how you would target one of them:
`terraform destroy -target=module.network_staging`.

## The next step you would take in real life

Two near-identical blocks is where `for_each` on the module itself starts paying
off:

```hcl
module "network" {
  source   = "./modules/network"
  for_each = {
    demo    = "10.20.0.0/16"
    staging = "10.30.0.0/16"
  }

  name       = each.key
  cidr_block = each.value
  azs        = ["us-east-1a", "us-east-1b"]
}
```

One block, any number of environments, addressed as
`module.network["staging"]`. Worth knowing it exists — and worth not reaching
for until the second copy actually appears, because a `for_each` written for one
caller is harder to read than the block it replaced.

**Done when:** two VPCs exist with different CIDRs, each with its own subnets and
its own instance.
