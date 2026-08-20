# A policy that expires what you stop tagging

Registries grow. Every rebuild leaves layers behind, and the bill is the first
thing that notices.

Read the policy this registry is running:

```
jq '.storage.retention' /root/registry/etc/config.json
```{{exec}}

Two rules, and they answer different questions:

- **`deleteUntagged: true`** — a manifest nobody references any more goes.
  This is the one that reclaims most of the space, because every `docker push`
  to an existing tag orphans the manifest that tag used to point at.
- **`keepTags` with `mostRecentlyPushedCount: 3`** — of the tags matching
  `v.*`, keep the three most recently pushed and expire the rest.

**You can state how many it keeps: three.** That is the part of a retention
policy people cannot usually answer about their own registry, and it is the
part that matters during an incident when you want to roll back four versions.

## Push five and watch two go

```
cd /root/app
for N in 1 2 3 4 5; do
  printf 'FROM debian:12.5-slim\nRUN echo v%s > /marker\n' "$N" > Dockerfile
  docker build -q -t localhost:5000/platform/api:v$N . >/dev/null
  docker push -q localhost:5000/platform/api:v$N >/dev/null
  sleep 1
done
echo "tags now:"
curl -s http://localhost:5000/v2/platform/api/tags/list | jq -c .tags
```{{exec}}

Five tags. The policy runs on a schedule rather than on every push, so wait for
it:

```
echo "waiting for the retention cycle..."
for i in $(seq 1 8); do
  T=$(curl -s http://localhost:5000/v2/platform/api/tags/list | jq -r '.tags | length')
  [ "$T" -le 3 ] && { echo "down to $T tags"; break; }
  printf "."
  sleep 15
done
echo
curl -s http://localhost:5000/v2/platform/api/tags/list | jq -c .tags
docker logs zot 2>&1 | grep -c '"module":"retention"'
```{{exec}}

`["v3","v4","v5"]`. **`v1` and `v2` are gone, and nobody deleted them.**

## Prove the untagged half separately

Overwrite a tag and the manifest it used to point at becomes unreferenced:

```
cd /root/app
BEFORE=$(curl -s -I -H "Accept: application/vnd.oci.image.manifest.v1+json" \
  http://localhost:5000/v2/platform/api/manifests/v5 | tr -d '\r' | awk '/[Dd]ocker-[Cc]ontent-[Dd]igest/{print $2}')
echo "v5 currently points at ${BEFORE:0:24}..."
printf 'FROM debian:12.5-slim\nRUN echo replaced > /marker\n' > Dockerfile
docker build -q -t localhost:5000/platform/api:v5 . >/dev/null
docker push -q localhost:5000/platform/api:v5 >/dev/null
echo "the old manifest by digest: $(curl -s -o /dev/null -w '%{http_code}' \
  -H 'Accept: application/vnd.oci.image.manifest.v1+json' \
  http://localhost:5000/v2/platform/api/manifests/$BEFORE)"
```{{exec}}

`404` — and note it went immediately, not on the next retention cycle. **This
registry drops an orphaned manifest as soon as it is orphaned**, where ECR's
`expire untagged after N days` deliberately leaves a window. That window exists
so a mistaken overwrite is recoverable, and it is the reason ECR's rule is
`countUnit: days` rather than "now".

## The same thing on ECR

```
cat <<'HCL'
resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name
  policy = jsonencode({ rules = [
    { rulePriority = 1
      description  = "Expire untagged images after 7 days"
      selection    = { tagStatus = "untagged", countType = "sinceImagePushed",
                       countUnit = "days", countNumber = 7 }
      action       = { type = "expire" } },
    { rulePriority = 2
      description  = "Keep the 3 most recent tagged images"
      selection    = { tagStatus = "tagged", tagPrefixList = ["v"],
                       countType = "imageCountMoreThan", countNumber = 3 }
      action       = { type = "expire" } }
  ]})
}
HCL
```{{exec}}

Same two rules, same two questions. **Rules are evaluated in priority order and
the first match wins**, so an overly broad rule at priority 1 makes everything
below it dead code — which is the usual reason an ECR policy expires more than
its author intended.

**Done when:** three tags remain of the five you pushed, and you can say which
rule kept them.
