Four situations that all look like "Terraform is broken", and none of which are.

Somebody changed a resource in the console. A resource exists that Terraform
never created. The state file was deleted. And a refactor wants to destroy and
recreate a database that is perfectly healthy.

Every one has a repair that touches no infrastructure at all.

**What you will do**

1. **Detect drift** and resolve it deliberately — in either direction
2. **Import a resource** Terraform did not create, until `plan` is quiet
3. **Restore a deleted state file** from bucket versioning
4. **Move resources in state** without destroying anything

AWS here is [LocalStack](https://localstack.cloud) in a container, so the state
bucket, its versions and the resources are all real API objects.

```
terraform version
awslocal s3 ls
```{{exec}}
