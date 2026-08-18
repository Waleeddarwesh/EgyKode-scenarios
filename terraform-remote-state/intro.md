State on a laptop is state one person has. It cannot be reviewed, it is not
backed up, and the first time two people apply at once one of them silently
overwrites the other's resources — the state file has no idea a second copy
exists.

This moves it somewhere both of them can see, and adds the lock that makes the
second apply wait instead of guess.

**What you will do**

1. **Create the state bucket** — versioned, encrypted, closed to the public, and
   necessarily managed by state that is not yet in it
2. **Migrate** — with proof that nothing was destroyed and recreated
3. **Race two applies** — and read the error the loser gets
4. **Release a stale lock** — the right way, which is not `-lock=false`

AWS here is [LocalStack](https://localstack.cloud), running in a container. The
S3 API, the DynamoDB API and the Terraform backend all behave as they do in a
real account — with no bill and no credentials worth stealing.

```
curl -s http://localhost:4566/_localstack/health | head -c 200; echo
terraform version
```{{exec}}
