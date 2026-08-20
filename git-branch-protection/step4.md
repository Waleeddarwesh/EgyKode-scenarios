# Why "up to date" matters

A pull request is tested against the code as it was when you branched. `main`
does not wait for you.

```
export A="http://ci:CiPassw0rd!@localhost:3000"
curl -s -X PATCH "$A/api/v1/repos/ci/platform/branch_protections/main" \
  -H "Content-Type: application/json" \
  -d '{"block_on_outdated_branch":true,"enable_status_check":false,"status_check_contexts":[]}' \
  -o /dev/null -w 'require up to date: %{http_code}\n'
```{{exec}}

## Branch, then let main move underneath you

```
cd /root/platform
git fetch -q origin && git checkout -q -B feature/mine origin/main
echo "my change" >> service.txt
git add -A && git commit -qm "my change"
git push -q origin feature/mine 2>&1 | tail -1
PR=$(curl -s -X POST "$A/api/v1/repos/ci/platform/pulls" \
  -H "Content-Type: application/json" \
  -d '{"head":"feature/mine","base":"main","title":"My change"}')
export NUM=$(echo "$PR" | tr ',' '\n' | grep -o '"number":[0-9]*' | head -1 | cut -d: -f2)
echo "PR $NUM opened against main"
```{{exec}}

Now somebody else merges first. That is all this is — a normal Tuesday:

```
curl -s -X PATCH "$A/api/v1/repos/ci/platform/branch_protections/main" \
  -H "Content-Type: application/json" -d '{"enable_push":true}' -o /dev/null
SHA=$(curl -s "$A/api/v1/repos/ci/platform/contents/README.md?ref=main" | grep -o '"sha":"[^"]*"' | head -1 | cut -d'"' -f4)
C=$(printf 'someone else got there first\n' | base64 | tr -d '\n')
curl -s -X PUT "$A/api/v1/repos/ci/platform/contents/README.md" \
  -H "Content-Type: application/json" \
  -d "{\"content\":\"$C\",\"message\":\"another team merges\",\"branch\":\"main\",\"sha\":\"$SHA\"}" \
  -o /dev/null -w 'main moves on: %{http_code}\n'
curl -s -X PATCH "$A/api/v1/repos/ci/platform/branch_protections/main" \
  -H "Content-Type: application/json" -d '{"enable_push":false}' -o /dev/null
```{{exec}}

## Your PR is still green, and still wrong

```
sleep 3
curl -s -X POST "$A/api/v1/repos/ci/platform/pulls/$NUM/merge" \
  -H "Content-Type: application/json" -d '{"Do":"merge"}' \
  -w '\nHTTP %{http_code}\n'
```{{exec}}

`405`. Nothing about your branch changed and nothing about it broke — but what
it was tested *against* no longer exists.

**This is the failure the setting exists for.** Two PRs, each green on its own,
each touching different files, merged minutes apart. Nothing conflicts, so Git
merges both cleanly, and `main` is broken by a combination neither build ever
saw. A renamed function in one and a new caller in the other is the classic
pair — no textual conflict, no compiling code.

Requiring up-to-date means the branch is re-tested against what `main` *is*, not
against what it was.

## Catch up, and it opens

```
cd /root/platform
git fetch -q origin
git merge -q --no-edit origin/main 2>&1 | tail -2
git push -q origin feature/mine 2>&1 | tail -1
sleep 3
curl -s -X POST "$A/api/v1/repos/ci/platform/pulls/$NUM/merge" \
  -H "Content-Type: application/json" -d '{"Do":"merge"}' \
  -w '\nHTTP %{http_code}\n'
```{{exec}}

## The cost, said plainly

This setting has a price and it is worth knowing before you turn it on. On a
busy repository every merge invalidates every other open PR, so they queue:
update, wait for CI, and if someone beat you again, do it once more. Ten active
PRs on a repository with a twenty-minute build spend the afternoon rebasing.

That is what **merge queues** exist to solve — the server batches the pending
changes, tests them together once, and merges the batch. Turn on
"require up to date" when a broken `main` costs more than the waiting does, and
reach for a merge queue when the waiting starts costing more than the breakage.

**Done when:** the outdated PR was refused, and merged after catching up.
