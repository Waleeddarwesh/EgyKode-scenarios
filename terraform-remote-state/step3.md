# Race two applies

State in a shared bucket solves visibility and creates a new problem: two people
can now write to the same file at the same time. The lock table is what stops
that being a coin toss.

Add something slow enough to race against:

```
cd ~/platform
cat > slow.tf <<'TF'
resource "terraform_data" "slow_step" {
  provisioner "local-exec" {
    command = "sleep 25"
  }
}
TF
terraform init -input=false > /dev/null
echo ready
```{{exec}}

Start an apply in the background, give it a moment to take the lock, then run a
second one — the way a colleague would, from their own machine, with no idea you
had started:

```
cd ~/platform
nohup terraform apply -auto-approve -input=false > /tmp/first.log 2>&1 &
echo "first apply started; waiting for it to take the lock"
sleep 8
terraform apply -auto-approve -input=false
echo "second apply exit code: $?"
```{{exec}}

```
Error: Error acquiring the state lock

Lock Info:
  ID:        f4ddd158-73ea-df92-e848-4f801f8ffb5a
  Operation: OperationTypeApply
  Who:       root@host
  Created:   ...
```

**The second apply refused to start.** It did not queue, it did not merge, and
it certainly did not proceed — it read the lock item out of DynamoDB, saw
somebody else holding it, and stopped.

Without that table both applies would have read the same state, done their work,
and written their own version over the top. The loser's resources stay in AWS
and vanish from state, which is the worst of both worlds: you are paying for
infrastructure Terraform no longer knows exists, and the next `destroy` leaves
it running.

The `Lock Info` block is not decoration. **`Who` and `Created` are how you find
out whether to wait or intervene** — a lock two minutes old belongs to a running
apply, and a lock from Tuesday does not.

Wait for the first one to finish:

```
cd ~/platform
wait
tail -2 /tmp/first.log
terraform plan -detailed-exitcode -input=false > /dev/null; echo "plan exit code: $?"
```{{exec}}

It completed normally. The lock was released, and the second apply — the one
that failed — changed nothing at all.

**Done when:** the first apply has finished, the lock is released, and a plan
reports no changes.
