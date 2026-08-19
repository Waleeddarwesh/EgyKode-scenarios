# Query the logs

A log group you cannot query is a more expensive `/var/log`. Find the errors:

```
awslocal logs filter-log-events \
  --log-group-name /egykode/lab/app \
  --filter-pattern ERROR \
  --query 'events[].message' --output text
```{{exec}}

## Stop. Check whether that filter did anything

The command above returned your ERROR lines. Now ask whether the *pattern* is
what selected them:

```
echo "no pattern at all:"
awslocal logs filter-log-events --log-group-name /egykode/lab/app --query 'length(events)'
echo "pattern ERROR:"
awslocal logs filter-log-events --log-group-name /egykode/lab/app \
  --filter-pattern 'ERROR' --query 'length(events)'
echo "pattern that should match nothing on earth:"
awslocal logs filter-log-events --log-group-name /egykode/lab/app \
  --filter-pattern 'ZZZNOMATCHZZZ' --query 'length(events)'
```{{exec}}

**The same count every time, including for the nonsense pattern.** LocalStack
stores log events and serves them back, but it does not implement filter
patterns at all — the argument is accepted and ignored. The first query only
*looked* like it worked because every event it returned happened to be one you
would have wanted.

Keep that. It is the most useful thing in this scenario: **an emulator that
accepts your argument is not the same as one that honours it**, and the way you
find out is to run the query that must fail and check that it does. This is the
same test you would run against a real alert before trusting it.

## What the pattern syntax actually is, on real AWS

Worth knowing before you write one against a real log group, because none of it
can be demonstrated here:

- `ERROR` matches the term anywhere in the message
- `"ERROR database"` in quotes matches that exact phrase
- `?ERROR ?timeout` matches either term
- `ERR.*` matches **nothing** — filter patterns are a small term-matching
  language, not regex, and a malformed pattern is not an error. It returns
  silence, which looks exactly like an application that had no problems.

That last one is why a filter pattern is worth testing deliberately: on real
AWS the failure mode is a query that quietly answers "no errors".

## Bound it by time, or you will read the whole group

```
NOW=$(($(date +%s) * 1000))
awslocal logs filter-log-events \
  --log-group-name /egykode/lab/app \
  --filter-pattern ERROR \
  --start-time $((NOW - 900000)) \
  --query 'events[].{at:timestamp,msg:message}' --output table
```{{exec}}

Fifteen minutes back. On a real group this is the difference between a query
that returns and one that scans months of data and bills you for it.

**This one is real here.** Unlike the pattern, the time window is honoured —
push `--start-time` into the future and you get zero events back, which is the
check that proves it rather than assumes it:

```
NOW=$(($(date +%s) * 1000))
echo "window starting 10 minutes from now: $(awslocal logs filter-log-events \
  --log-group-name /egykode/lab/app --start-time $((NOW + 600000)) --query 'length(events)')"
echo "window ending 10 days ago:           $(awslocal logs filter-log-events \
  --log-group-name /egykode/lab/app --end-time $((NOW - 864000000)) --query 'length(events)')"
```{{exec}}

Zero and zero. So a time-bounded query against this environment is a real
query; a pattern-bounded one is not.

## Turn the pattern into a metric

Querying is what you do *after* someone notices. A **metric filter** evaluates
the same pattern on every incoming event and increments a metric, so the logs
can drive an alarm instead of waiting to be read:

```
awslocal logs put-metric-filter \
  --log-group-name /egykode/lab/app \
  --filter-name error-count \
  --filter-pattern 'ERROR' \
  --metric-transformations \
    metricName=ApplicationErrors,metricNamespace=EgyKode/Ops,metricValue=1
awslocal logs describe-metric-filters \
  --log-group-name /egykode/lab/app \
  --query 'metricFilters[].{filter:filterName,pattern:filterPattern,metric:metricTransformations[0].metricName}' \
  --output table
```{{exec}}

`metricValue=1` counts occurrences. It can also extract a number out of the
line — latency, bytes, a queue depth — which is how a log line becomes a
graphable series without the application ever knowing CloudWatch exists.

**And this one is configuration only, here.** LocalStack stores the metric
filter — you can read it back, which is what the check on this step looks at —
but it never evaluates it, so `ApplicationErrors` will not increment no matter
how many ERROR lines arrive. On real AWS this is the join between the two
halves of the lab: the logs feed the metric, and the metric feeds the alarm you
build next. Here you are writing that wiring correctly without being able to
watch it carry current.

**Done when:** the events come back from a time-bounded query, you have seen the
pattern argument make no difference, and the metric filter is configured.
