"Public subnet" and "private subnet" are not settings. There is no checkbox, and
nothing in AWS stores the words — a subnet is public because a route table sends
its traffic to an internet gateway, and private because it does not.

Everything else in this scenario follows from that one fact.

**What you will do**

1. **Lay out four subnets** across two availability zones
2. **Add both gateways** — and see why one costs nothing and the other bills by
   the hour
3. **Write the route tables**, then point at the exact entry that makes a subnet
   public
4. **Destroy it**, and check that the Elastic IP went with the NAT Gateway

AWS here is [LocalStack](https://localstack.cloud) in a container: real VPC,
subnet, gateway and route table objects you can inspect with the AWS CLI.

```
awslocal ec2 describe-availability-zones --query 'AvailabilityZones[:4].ZoneName' --output text
terraform version
```{{exec}}
