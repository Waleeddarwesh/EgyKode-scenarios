# Buckets that are private by construction

Two buckets, closed from the moment they exist rather than closed later:

```
for B in platform-tfstate platform-logs; do
  awslocal s3api create-bucket --bucket $B >/dev/null 2>&1
  awslocal s3api put-public-access-block --bucket $B \
    --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
done
awslocal s3api get-public-access-block --bucket platform-tfstate \
  --query PublicAccessBlockConfiguration
```{{exec}}

**All four, not one.** They stop different things: `BlockPublicAcls` refuses a
new public ACL, `IgnorePublicAcls` neutralises ones already there,
`BlockPublicPolicy` refuses a public bucket policy, and `RestrictPublicBuckets`
cuts off cross-account and anonymous access through a policy that is already
attached. Setting two of the four is how a bucket ends up public despite
somebody having "turned on public access block".

## A policy that refuses plaintext

```
cat > /root/s3/tls-only.json <<'JSON'
{
  "Version": "2012-10-17",
  "Statement": [{
    "Sid": "DenyInsecureTransport",
    "Effect": "Deny",
    "Principal": "*",
    "Action": "s3:*",
    "Resource": [
      "arn:aws:s3:::platform-tfstate",
      "arn:aws:s3:::platform-tfstate/*"
    ],
    "Condition": { "Bool": { "aws:SecureTransport": "false" } }
  }]
}
JSON
awslocal s3api put-bucket-policy --bucket platform-tfstate \
  --policy file:///root/s3/tls-only.json
awslocal s3api get-bucket-policy --bucket platform-tfstate --query Policy --output text | jq -c '.Statement[0].Resource'
```{{exec}}

**Both ARNs.** Bucket-level actions like `ListBucket` are authorised against the
bucket ARN; object actions against `/*`. A policy carrying only one of them
half-works, which is worse than failing — the deny applies to some calls and
not others, and the gap is discovered by an audit rather than by an error.

## Now find out whether it is enforced

The endpoint here is plain HTTP. Every single call you have made is
`aws:SecureTransport = false`, so that policy should deny *everything*:

```
echo "test" > /tmp/probe.txt
awslocal s3 cp /tmp/probe.txt s3://platform-tfstate/probe.txt 2>&1 | tail -1
awslocal s3 cp s3://platform-tfstate/probe.txt - 2>&1 | tail -1
```{{exec}}

**It worked.** The policy is stored, returns from `get-bucket-policy`, and
denies nothing — this emulator implements bucket policy *storage*, not bucket
policy *evaluation*.

That is worth more than a working demo would be. **Configuration that is
accepted is not configuration that is enforced**, and there is no error to tell
you which one you have. The same shape catches people on real AWS in the other
direction: a policy that *is* enforced and denies more than intended, discovered
when a service breaks.

The rule to carry: **test a deny by making the request it should refuse.** If
you cannot make that request fail, you have not tested the policy — you have
read it. On a real account, the check for this one is a `curl http://` against
the bucket endpoint, which must return `AccessDenied`.

**Done when:** both buckets block public access all four ways, and the state
bucket carries a TLS-only policy naming both ARNs — with you knowing which half
of that this environment actually enforces.
