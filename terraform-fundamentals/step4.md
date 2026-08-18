# Destroy, and check rather than assume

Note what exists before you remove it, so you have something to check against:

```
cd ~/infra
terraform output -raw instance_id > /tmp/was_instance
terraform output -raw bucket_name > /tmp/was_bucket
cat /tmp/was_instance /tmp/was_bucket
```{{exec}}

Read the destroy plan first. It is a plan like any other, and it is the one
worth reading most carefully:

```
cd ~/infra
terraform plan -destroy | tail -12
```{{exec}}

Four resources to destroy, each named. **On a real account this is the last
moment before something is gone**, and the habit of reading it is the difference
between destroying a test stack and destroying the production database that
somebody imported into the same state file.

```
cd ~/infra
terraform destroy -auto-approve | tail -4
```{{exec}}

## Now check, rather than believe the output

```
awslocal ec2 describe-instances \
  --instance-ids $(cat /tmp/was_instance) \
  --query 'Reservations[].Instances[].State.Name' --output text 2>&1 | tail -1
awslocal s3 ls | grep "$(cat /tmp/was_bucket)" || echo "bucket is gone"
```{{exec}}

The instance reports `terminated` and the bucket is not listed.

**`terraform destroy` reporting success is not proof.** It reports what it asked
for, and a resource can survive the request — a bucket that is not empty, a
security group still attached to something, a resource protected by
`prevent_destroy`, or a dependency in another state file. The API is the
authority, and checking it takes one command.

```
cd ~/infra
terraform state list | wc -l
terraform show | head -3
```{{exec}}

Empty state, no managed resources.

## The one that costs money in real life

```
awslocal ec2 describe-volumes --query 'Volumes[].[VolumeId,State]' --output text 2>/dev/null | head -5
awslocal s3 ls
```{{exec}}

Nothing left. On real AWS the usual survivors are unattached EBS volumes,
snapshots, Elastic IPs and load balancer logs in a bucket Terraform never
managed — all of which keep billing after the instance they belonged to is
gone, and none of which appear in `terraform destroy` output because Terraform
never knew about them.

That is why the cleanup section of every lab in this path ends with a CLI
command rather than an assurance.

**Done when:** the instance is terminated, the bucket is gone, and
`terraform state list` is empty.
