# Destroy, and check the Elastic IP

Note what is billing before you remove it:

```
cd ~/network
awslocal ec2 describe-nat-gateways \
  --query 'NatGateways[?State==`available`].[NatGatewayId,SubnetId]' --output text
awslocal ec2 describe-addresses --query 'Addresses[].[PublicIp,AllocationId]' --output text
```{{exec}}

One NAT gateway, one Elastic IP. On a real account that pair is about $32 a
month for the gateway, plus data processing — and the address bills separately
the moment it stops being attached to anything.

Read the destroy plan:

```
cd ~/network
terraform plan -destroy | grep -E "will be destroyed|Plan:" | tail -12
```{{exec}}

```
cd ~/network
terraform destroy -auto-approve | tail -3
```{{exec}}

## Check the account, not the output

```
awslocal ec2 describe-nat-gateways \
  --query 'NatGateways[?State!=`deleted`].[NatGatewayId,State]' --output text
echo "--- addresses still allocated:"
awslocal ec2 describe-addresses --query 'Addresses[].[PublicIp,AllocationId]' --output text
echo "--- vpcs:"
awslocal ec2 describe-vpcs --filters Name=tag:Name,Values=egykode \
  --query 'Vpcs[].VpcId' --output text
```{{exec}}

All three empty. The NAT gateway is gone, **the Elastic IP was released**, and
the VPC with it.

## Why the Elastic IP is the one to check

This is the classic orphan. An Elastic IP costs nothing while it is attached to
something running, and starts charging by the hour the moment it is not. Delete
a NAT gateway by hand — through the console, during an incident, at speed — and
the address it was using stays allocated to your account, attached to nothing,
quietly billing.

Terraform released it here because `aws_eip.nat` was in state and the destroy
covered it. Nothing about deleting a NAT gateway releases an address on its own.

The same pattern accounts for most of the surprise line items on an AWS bill:

- **Elastic IPs** not attached to a running instance
- **EBS volumes** left behind when an instance is terminated without
  `delete_on_termination`
- **Snapshots** of volumes that no longer exist
- **Load balancer logs** in a bucket Terraform never managed

None of them appear in `terraform destroy` output, because Terraform never knew
about them. That is why the cleanup section of every lab in this path ends with
a CLI command rather than an assurance.

```
cd ~/network
terraform state list | wc -l
```{{exec}}

Empty state and an empty account — those are two different claims, and you just
checked both.

**Done when:** no NAT gateway, no allocated Elastic IP, no VPC, and empty state.
