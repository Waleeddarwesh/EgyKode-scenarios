Three directories of near-identical Terraform is the problem a module solves.
Not by removing the duplication after the fact, but by making the thing you
repeat a single object with inputs — so "another environment" is four lines
rather than a copied directory that starts drifting the same afternoon.

**What you will do**

1. **Write a network module** that computes its subnets from whatever CIDR it is
   given, and exposes the ids other things need
2. **Write a compute module that never mentions a VPC** — and see why that
   restraint is what makes it reusable
3. **Call the network module twice** with different CIDRs, and confirm the two
   networks are genuinely independent

AWS here is [LocalStack](https://localstack.cloud) in a container, so the VPCs,
subnets and instances are real API objects you can inspect with the AWS CLI.

```
awslocal ec2 describe-vpcs --query 'Vpcs[].[VpcId,CidrBlock]' --output text
terraform version
```{{exec}}
