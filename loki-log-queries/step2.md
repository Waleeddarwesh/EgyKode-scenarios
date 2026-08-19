Loki does not index your log lines. It indexes the **labels**, compresses
everything else, and brute-force scans whatever streams you selected.

That one design decision is why Loki is cheap where Elasticsearch is expensive
— an Elasticsearch index of full text often exceeds the logs it describes — and
it is also why the first query everybody writes is the one that times out.

```
{namespace="production", app="api"} |= "ERROR"    # select 1 stream, scan it
{namespace="production"} |= "ERROR"               # select ~2, scan them
{} |= "ERROR"                                     # select everything. no.
```

The selector runs first and decides how much data exists. The filter runs
second, over whatever survived.

## See the difference

```
curl -sG localhost:31000/loki/api/v1/query_range \
  --data-urlencode 'query={namespace="production"} |= "ERROR"' \
  --data-urlencode 'since=15m' --data-urlencode 'limit=5' \
  | grep -o '"totalLinesProcessed":[0-9]*'
```{{exec}}

```
curl -sG localhost:31000/loki/api/v1/query_range \
  --data-urlencode 'query={namespace="production", app="api"} |= "ERROR"' \
  --data-urlencode 'since=15m' --data-urlencode 'limit=5' \
  | grep -o '"totalLinesProcessed":[0-9]*'
```{{exec}}

Same answer, less scanned — measured here at 373 lines against 247, because
`web` is in that namespace too and every one of its lines had to be read before
the filter could reject it.

On a node with two Deployments that is a rounding error. On a cluster with four
hundred it is the difference between a result and a timeout, and the query that
times out is always the one where the filter was asked to do the selector's
job.

## The one that turns logs into a metric

```
curl -sG localhost:31000/loki/api/v1/query \
  --data-urlencode 'query=sum(rate({namespace="production"} |= "ERROR" [5m])) by (app)' \
  | grep -o '"app":"[a-z]*"\|"value":\[[^]]*\]'
```{{exec}}

An error rate derived from log lines, graphable beside Prometheus data and
alertable the same way.

## Your turn

Write **one query** that returns the errors from a single Deployment over the
last fifteen minutes, and save it:

```
cat > /root/query.logql <<'EOF'
PUT YOUR QUERY HERE
EOF
cat /root/query.logql
```{{exec}}

The check runs exactly what you wrote and requires three things of it: that the
lines it returns are errors, that they come from **one** Deployment and not
several, and that the selector does the narrowing rather than the filter.
