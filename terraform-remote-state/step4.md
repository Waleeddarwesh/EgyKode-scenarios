# When a lock goes stale

The lock is released when the apply finishes. An apply that *does not* finish —
a laptop that sleeps, a CI runner killed mid-job, a lost network — leaves the
lock behind, and every subsequent run fails on a lock whose owner no longer
exists.

First, look at what is actually in the table:

```
curl -s -X POST http://localhost:4566/ \
  -H 'X-Amz-Target: DynamoDB_20120810.Scan' \
  -H 'Content-Type: application/x-amz-json-1.0' \
  -d '{"TableName":"egykode-tfstate-locks"}'
echo
```{{exec}}

One item, and **it is not a lock.** `...terraform.tfstate-md5` holds a digest of
the state file, permanently, so Terraform can detect a state file that changed
underneath it. A real lock is a separate item carrying `Info`, `Who` and
`Created`.

Worth knowing before an incident: "the lock table has a row in it" is not the
same as "something is locked", and the row that is always there has caught out
plenty of people at three in the morning.

## Create a stale lock

Kill an apply while it holds the lock:

```
cd ~/platform
terraform apply -auto-approve -input=false -replace=terraform_data.slow_step > /tmp/killed.log 2>&1 &
APPLY_PID=$!
sleep 8
kill -9 $APPLY_PID
sleep 2
echo "killed the apply mid-run"
curl -s -X POST http://localhost:4566/ \
  -H 'X-Amz-Target: DynamoDB_20120810.Scan' \
  -H 'Content-Type: application/x-amz-json-1.0' \
  -d '{"TableName":"egykode-tfstate-locks"}' | grep -o '"LockID": {"S": "[^"]*"'
```{{exec}}

Two items now. The second is the lock, and nothing is coming back to release it.

```
cd ~/platform
terraform plan -input=false 2>&1 | grep -A6 -i "error acquiring"
```{{exec}}

Every command from here on fails the same way, for everybody.

## Release it — the right way

The error message gives you an ID. **It also gives you a different ID, and
picking the wrong one fails silently:**

```text
StatusCode: 400, RequestID: 36c74cd7-0c70-4f6a-8040-969be568916f,
Lock Info:
  ID:        aa1f8293-078b-baed-b3c7-7ae04e19ebeb
```

`RequestID` identifies the DynamoDB call that just failed. The lock is the one
under `Lock Info`. Hand `force-unlock` the request ID and it reports nothing
useful and releases nothing, and you go round again wondering why.

```
cd ~/platform
LOCK_ID=$(terraform plan -input=false 2>&1 | grep "ID:" | grep -v RequestID | head -1 | grep -oE "[0-9a-f-]{36}")
echo "lock id: $LOCK_ID"
terraform force-unlock -force "$LOCK_ID"
```{{exec}}

```
Terraform state has been successfully unlocked!
```

**`force-unlock` takes the specific lock ID on purpose.** It is not a "clear all
locks" button — passing an ID means you looked at the lock, read `Who` and
`Created`, and decided that particular one is dead. A command that unlocked
blindly would be used blindly, and the first casualty would be a colleague's
apply that was running perfectly well.

Confirm:

```
cd ~/platform
terraform plan -detailed-exitcode -input=false > /dev/null; echo "plan exit code: $?"
```{{exec}}

## What not to do

`-lock=false` exists. It appears in a lot of answers on the internet, and it is
the wrong tool here:

```text
terraform apply -lock=false     # do not
```

It does not release the stale lock — it **ignores locking entirely** for that
run. If the original process was somehow still alive, you now have exactly the
concurrent write the lock existed to prevent, and the losing side's resources
disappear from state while continuing to bill.

Diagnose the lock, then release that lock. There is no third option worth taking.

**Done when:** the stale lock is released and Terraform runs normally again.
