# Versioning, and getting a deleted object back

The state bucket holds the one file that describes everything Terraform
manages. Deleting it is one keystroke, and without versioning the recovery is a
manual re-import of every resource.

```
awslocal s3api put-bucket-versioning --bucket platform-tfstate \
  --versioning-configuration Status=Enabled
awslocal s3api get-bucket-versioning --bucket platform-tfstate
```{{exec}}

## Put something in it that matters

```
printf '{"version":4,"serial":7,"resources":["the whole platform"]}\n' > /tmp/terraform.tfstate
awslocal s3 cp /tmp/terraform.tfstate s3://platform-tfstate/terraform.tfstate
awslocal s3 ls s3://platform-tfstate/
```{{exec}}

## Delete it

```
awslocal s3 rm s3://platform-tfstate/terraform.tfstate
echo "--- what does a listing show now? ---"
awslocal s3 ls s3://platform-tfstate/
echo "(nothing above this line means the object is gone as far as any normal read is concerned)"
awslocal s3 cp s3://platform-tfstate/terraform.tfstate - 2>&1 | tail -1
```{{exec}}

Gone, and a read fails. That is exactly what it looks like without versioning
too — which is why the next command is the one worth knowing by heart.

## It is not gone

```
awslocal s3api list-object-versions --bucket platform-tfstate --prefix terraform.tfstate \
  --query '{versions: Versions[].{id:VersionId,latest:IsLatest}, deleteMarkers: DeleteMarkers[].{id:VersionId,latest:IsLatest}}'
```{{exec}}

**The object is still there and a delete marker sits on top of it.** That is all
a delete does on a versioned bucket: it writes a marker that becomes the latest
version, so ordinary reads find nothing while the data is untouched underneath.

## Recover it

Remove the marker — and note that recovery means *deleting a version*, which
reads backwards the first time:

```
MARKER=$(awslocal s3api list-object-versions --bucket platform-tfstate \
  --prefix terraform.tfstate --query 'DeleteMarkers[?IsLatest].VersionId' --output text)
echo "removing delete marker $MARKER"
awslocal s3api delete-object --bucket platform-tfstate \
  --key terraform.tfstate --version-id "$MARKER"
awslocal s3 ls s3://platform-tfstate/
awslocal s3 cp s3://platform-tfstate/terraform.tfstate - 2>/dev/null
```{{exec}}

The file, with its contents, recovered by removing the thing that was hiding it.

## Two things this does not save you from

**`aws s3 rm --recursive` on a bucket with `--include "*"`** still writes a
delete marker per object, so recovery is per-object unless you script it. Write
that script before you need it.

**A version deleted by version id is gone for good.** The command you just ran
to recover the file is the same command that destroys a version permanently —
the only difference is which version id you hand it. That is why the safety net
underneath versioning is `MFA Delete` on a production state bucket, and why the
state bucket is the one place it is worth the friction.

**And versioning costs storage.** Every overwrite of a large state file keeps
the previous copy, which is what lifecycle rules on *noncurrent* versions are
for — the S3 equivalent of the registry retention policy in step 2, doing the
same job for the same reason.

**Done when:** the state bucket has versioning on, and you deleted an object and
got it back.
