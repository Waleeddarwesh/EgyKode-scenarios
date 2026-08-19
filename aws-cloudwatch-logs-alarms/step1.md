# The metric the hypervisor cannot see

Wait for setup, then look at what EC2 gives you for free:

```
until curl -s --max-time 5 http://localhost:4566/_localstack/health 2>/dev/null | grep -qE '"logs": *"(available|running)"'; do sleep 3; done
echo "LocalStack ready"
awslocal cloudwatch list-metrics --namespace AWS/EC2 --query 'Metrics[].MetricName' --output text
```{{exec}}

## Why memory is not in that list

EC2's default metrics are collected by the **hypervisor**, from outside the
instance. From there you can see how much CPU time the virtual machine was
given, how many bytes crossed its network interfaces, how many disk operations
its volumes performed. All of that is visible from the outside.

**Memory used and disk space free are not.** They are facts about what the
operating system inside the instance is doing with the resources it was handed.
The hypervisor sees a block of RAM assigned to the guest; it cannot see how much
of it the guest considers free, because that is bookkeeping inside the kernel it
is hosting. Same for a filesystem: the hypervisor sees reads and writes, not
inodes and free blocks.

So anything from inside the guest has to be **pushed out by an agent running
there** — the CloudWatch agent, in practice. That is the whole distinction:
infrastructure metrics arrive for free, guest metrics cost you an agent.

## Publish one, the way the agent would

```
awslocal cloudwatch put-metric-data \
  --namespace EgyKode/Ops \
  --metric-name MemoryUtilization \
  --unit Percent \
  --value 78.4 \
  --dimensions InstanceId=i-egykodelab
echo "published"
awslocal cloudwatch list-metrics --namespace EgyKode/Ops \
  --query 'Metrics[].{name:MetricName,dims:Dimensions[0].Value}' --output table
```{{exec}}

A **custom namespace**, because anything beginning `AWS/` is reserved. Real
CloudWatch refuses a `PutMetricData` into `AWS/EC2` with *"The value AWS/EC2 for
parameter Namespace is not supported"*.

Try it here and it will be accepted — **LocalStack does not enforce that rule**,
which is worth knowing before you trust an emulator to tell you your code is
correct. The check on this step rejects it anyway, because the habit is what
matters and real AWS will not be so forgiving.

The dimension is what lets one alarm template serve every instance instead of
one alarm per host.

## Now the logs

Same argument, one layer up: an application's log file is inside the instance,
so something inside has to ship it.

```
awslocal logs create-log-group --log-group-name /egykode/lab/app
awslocal logs create-log-stream --log-group-name /egykode/lab/app --log-stream-name i-egykodelab
NOW=$(($(date +%s) * 1000))
awslocal logs put-log-events \
  --log-group-name /egykode/lab/app \
  --log-stream-name i-egykodelab \
  --log-events \
    timestamp=$((NOW-5000)),message="INFO  startup complete in 412ms" \
    timestamp=$((NOW-4000)),message="INFO  GET /healthz 200 3ms" \
    timestamp=$((NOW-3000)),message="ERROR database timeout after 5000ms" \
    timestamp=$((NOW-2000)),message="INFO  GET /api/orders 200 88ms" \
    timestamp=$((NOW-1000)),message="ERROR upstream payments returned 503" \
  --query 'nextSequenceToken' --output text
awslocal logs describe-log-streams --log-group-name /egykode/lab/app \
  --query 'logStreams[].{stream:logStreamName,events:storedBytes}' --output table
```{{exec}}

**Timestamps are milliseconds, not seconds.** A value in seconds lands in 1970,
the event is silently outside every time window you will query, and the log
group looks empty while `storedBytes` insists otherwise. It is the single most
common thing to get wrong here.

**Done when:** a custom `MemoryUtilization` metric exists in your own namespace,
and the log group holds the events you shipped.
