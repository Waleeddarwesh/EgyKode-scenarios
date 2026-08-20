# A registry that scans what you push

Wait for setup, then build something worth scanning and push it:

```
until [ "$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 http://localhost:5000/v2/ 2>/dev/null)" = "200" ]; do sleep 3; done
mkdir -p /root/app && cd /root/app
cat > Dockerfile <<'DOCKER'
FROM debian:12.5-slim
RUN apt-get update && apt-get install -y --no-install-recommends curl \
 && rm -rf /var/lib/apt/lists/*
DOCKER
docker build -q -t localhost:5000/platform/api:v1 .
docker push localhost:5000/platform/api:v1 | tail -2
curl -s http://localhost:5000/v2/_catalog
```{{exec}}

**`debian:12.5-slim`, a frozen point release** — not an end-of-life image. That
distinction decides whether any of this works: an EOL distribution ships no
fixes, so nearly everything it carries is unfixable, and a scanner filtered to
actionable findings reports almost nothing about the most neglected image on the
machine.

## Nobody asked it to scan

```
sleep 20
curl -s -X POST http://localhost:5000/v2/_zot/ext/search \
  -H 'Content-Type: application/json' \
  -d '{"query":"{ CVEListForImage(image:\"platform/api:v1\") { Tag CVEList { Id Severity Title } } }"}' \
  | jq '.data.CVEListForImage.CVEList | length as $n | {found:$n, first:(.[0:3])}'
```{{exec}}

If that returns `null` the vulnerability database is still downloading — it is
about 108 MiB on first run. Give it a minute and ask again:

```
for i in $(seq 1 12); do
  R=$(curl -s -X POST http://localhost:5000/v2/_zot/ext/search -H 'Content-Type: application/json' \
    -d '{"query":"{ CVEListForImage(image:\"platform/api:v1\") { CVEList { Id Severity } } }"}')
  echo "$R" | grep -q '"Id"' && break
  printf "."
  sleep 15
done
echo
echo "$R" | jq -r '[.data.CVEListForImage.CVEList[].Severity] | group_by(.) | map({severity:.[0], count:length})'
```{{exec}}

**Scanning happened because the image arrived**, not because a pipeline stage
ran. That is the property worth having: an image nobody remembered to scan is
still scanned, including one pushed by a job you have never read.

## Read the findings, filtered the way a gate would

```
curl -s -X POST http://localhost:5000/v2/_zot/ext/search -H 'Content-Type: application/json' \
  -d '{"query":"{ CVEListForImage(image:\"platform/api:v1\") { CVEList { Id Severity Title } } }"}' \
  | jq -r '.data.CVEListForImage.CVEList[] | select(.Severity=="CRITICAL" or .Severity=="HIGH") | "\(.Severity)\t\(.Id)\t\(.Title[0:60])"' \
  | head -8
```{{exec}}

## The same thing on ECR

The mechanism is identical and the wiring is not, so it is worth seeing both:

| Here | On ECR |
| --- | --- |
| `extensions.search.cve` in the registry config | `imageScanningConfiguration { scanOnPush = true }` on the repository |
| `CVEListForImage` over GraphQL | `aws ecr describe-image-scan-findings --image-id imageTag=v1` |
| Findings keyed by severity | `imageScanFindings.findingSeverityCounts` |

**And the same trap on both.** A scan that cannot reach its database exits
without findings, which looks exactly like a clean image. Whatever registry you
use, the question is never "did the scan pass" — it is "did the scan run, and
what did it look at".

**Done when:** `platform/api:v1` is in the registry and the registry can tell
you what is wrong with it.
