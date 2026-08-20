# A pull request that cannot merge

Protection stops direct pushes. It does not yet stop a *broken* change arriving
through the front door.

```
export A="http://ci:CiPassw0rd!@localhost:3000"
curl -s -X PATCH "$A/api/v1/repos/ci/platform/branch_protections/main" \
  -H "Content-Type: application/json" \
  -d '{"enable_status_check":true,"status_check_contexts":["ci/build"]}' \
  -o /dev/null -w 'require ci/build: %{http_code}\n'
```{{exec}}

`ci/build` is now a **required context**. Nothing produces it yet, which is
itself worth seeing.

## Open a pull request

```
cd /root/platform
echo "a change worth reviewing" >> README.md
git add -A && git commit -qm "add a line"
git push -q origin feature/first-change 2>&1 | tail -1
PR=$(curl -s -X POST "$A/api/v1/repos/ci/platform/pulls" \
  -H "Content-Type: application/json" \
  -d '{"head":"feature/first-change","base":"main","title":"Add a line"}')
echo "$PR" | tr ',' '\n' | grep -E '"number"|"mergeable"' | head -2
export NUM=$(echo "$PR" | tr ',' '\n' | grep -o '"number":[0-9]*' | head -1 | cut -d: -f2)
echo "PR number: $NUM"
```{{exec}}

## Report a failing build against it

This is what a CI system does at the end of a run — one API call saying "this
commit, this context, this result":

```
cd /root/platform
SHA=$(git rev-parse HEAD)
curl -s -X POST "$A/api/v1/repos/ci/platform/statuses/$SHA" \
  -H "Content-Type: application/json" \
  -d '{"context":"ci/build","state":"failure","description":"3 tests failed"}' \
  -o /dev/null -w 'post failing status: %{http_code}\n'
curl -s "$A/api/v1/repos/ci/platform/commits/$SHA/statuses" \
  | tr ',' '\n' | grep -E '"status"|"context"|"description"' | head -3
```{{exec}}

## Now try to merge it

```
curl -s -X POST "$A/api/v1/repos/ci/platform/pulls/$NUM/merge" \
  -H "Content-Type: application/json" -d '{"Do":"merge"}' \
  -w '\nHTTP %{http_code}\n'
```{{exec}}

```
{"message":"not allowed to merge [reason: Not all required status checks successful]"}
HTTP 405
```

**The server refused, and said which rule.** Not a warning, not a red icon
somebody might notice — the merge endpoint returned 405 and the change is still
outside `main`.

## Fix the build and watch it open

```
cd /root/platform
SHA=$(git rev-parse HEAD)
curl -s -X POST "$A/api/v1/repos/ci/platform/statuses/$SHA" \
  -H "Content-Type: application/json" \
  -d '{"context":"ci/build","state":"success","description":"all tests passed"}' \
  -o /dev/null -w 'post passing status: %{http_code}\n'
sleep 2
curl -s -X POST "$A/api/v1/repos/ci/platform/pulls/$NUM/merge" \
  -H "Content-Type: application/json" -d '{"Do":"merge"}' \
  -w '\nHTTP %{http_code}\n'
```{{exec}}

`200`, and the same change that was refused a moment ago is now on `main` —
because the *evidence* changed, not because anyone was asked twice.

**The context name is the contract.** A required context that nothing ever
posts blocks every merge forever, and a typo in it is the usual cause. Compare
what you required with what was posted:

```
curl -s "$A/api/v1/repos/ci/platform/branch_protections/main" \
  | tr ',' '\n' | grep -i status_check
```{{exec}}

**Done when:** a failing required check refused the merge, and a passing one
allowed it.
