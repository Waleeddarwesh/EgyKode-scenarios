# Alarm on something that matters

You now have `ApplicationErrors`, incremented by the logs themselves. Alarm on
it:

```
awslocal cloudwatch put-metric-alarm \
  --alarm-name egykode-lab-errors \
  --alarm-description "Application errors sustained over two minutes" \
  --namespace EgyKode/Ops \
  --metric-name ApplicationErrors \
  --statistic Sum \
  --period 60 \
  --evaluation-periods 2 \
  --threshold 5 \
  --comparison-operator GreaterThanThreshold \
  --treat-missing-data notBreaching
awslocal cloudwatch describe-alarms \
  --query 'MetricAlarms[].{name:AlarmName,metric:MetricName,threshold:Threshold,periods:EvaluationPeriods,missing:TreatMissingData}' \
  --output table
```{{exec}}

## Justifying every number in that command

An alarm nobody can justify gets silenced the first time it fires at 3am, and
then it is decoration. Each argument is a decision:

**`ApplicationErrors`, not `CPUUtilization`.** CPU is a resource, not a symptom.
A box at 90% CPU serving every request correctly is fine; a box at 4% CPU
returning 503 is an outage. Alarm on what the user experiences — errors,
latency, failed checks — and keep CPU for the graph you look at *after* the
alarm fires, when you are working out why.

**`Sum`, not `Average`.** Averaging a count is meaningless: ten errors in one
minute averaged across a five-minute window looks like two.

**`evaluation-periods 2`.** One bad minute is noise — a deploy, a restart, a
retried connection. Two consecutive breaches is a pattern. This is the single
biggest lever on whether people trust the alarm.

**`treat-missing-data notBreaching`.** A metric filter emits nothing when there
are no errors, so "no data" here means *healthy*. Leave the default and a quiet
service alarms all night. Note the inversion: for a heartbeat metric, missing
data means the opposite and `breaching` is correct. The right answer depends
entirely on what silence means for that metric.

## Check the shape of it

```
awslocal cloudwatch describe-alarms --alarm-names egykode-lab-errors \
  --query 'MetricAlarms[0].{state:StateValue,ns:Namespace,stat:Statistic,cmp:ComparisonOperator}' --output table
```{{exec}}

`INSUFFICIENT_DATA` is the honest state for an alarm that has not seen a full
evaluation window yet. It is not a failure, and an alarm that jumps straight to
`OK` before it has any data would be lying to you.

**Here it is also permanent.** LocalStack stores the alarm but never evaluates
it: publish a value far past the threshold and the state does not move -
measured. So what you are building in this step is the *configuration* of an
alarm, which is exactly what criterion 3 asks for, and not its behaviour. On a
real account the state moves to `ALARM` and something has to happen next.

## What this does not cover

The alarm has no action attached. On a real account this is where an SNS topic
goes, and the thing worth testing there is not the alarm but the **delivery** —
whether the page actually reaches a human at 3am. An alarm wired to a topic
nobody is subscribed to is the most common way a monitoring system is discovered
to be decorative, and it is discovered during the incident.

**Done when:** an alarm exists on `ApplicationErrors` with a threshold, more
than one evaluation period, and a deliberate choice about missing data.
