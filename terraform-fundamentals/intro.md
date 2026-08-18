Terraform's whole model is three verbs and one file. `plan` works out the
difference between what you wrote and what exists, `apply` closes it, and
`state` is how it remembers which real resource each line of your configuration
became.

Get those four things straight and everything else is detail.

**What you will do**

1. **Pin a provider** and take values in through variables, out through outputs
2. **Create an instance and a bucket** from one configuration
3. **Run apply twice** — and be able to say exactly why the second one does
   nothing
4. **Destroy it**, and confirm against the API rather than trusting the output

AWS here is [LocalStack](https://localstack.cloud) in a container. `awslocal` is
the AWS CLI with the endpoint already pointed at it, so every command reads the
way it would against a real account.

```
awslocal sts get-caller-identity
terraform version
```{{exec}}
