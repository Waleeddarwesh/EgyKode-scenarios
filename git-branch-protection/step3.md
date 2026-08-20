# CODEOWNERS, and who it asks

A rule that says "someone must approve" gets whoever is free. A rule that says
"the person responsible for *this path* must approve" gets the person who will
notice the problem.

```
export A="http://ci:CiPassw0rd!@localhost:3000"
curl -s "$A/api/v1/repos/ci/platform/collaborators" | tr ',' '\n' | grep '"login"'
```{{exec}}

`platform-lead` can review this repository. That matters more than it looks:
**CODEOWNERS silently ignores an owner who has no access**, which is the most
common reason a correct-looking file does nothing.

## Add the file

`main` is protected, so this goes through the API as the admin rather than by
pushing — which is itself the point of the previous step:

```
CONTENT=$(printf 'infra/.* @platform-lead\n' | base64 | tr -d '\n')
curl -s -X PATCH "$A/api/v1/repos/ci/platform/branch_protections/main" \
  -H "Content-Type: application/json" -d '{"enable_push":true}' -o /dev/null
curl -s -X POST "$A/api/v1/repos/ci/platform/contents/.gitea/CODEOWNERS" \
  -H "Content-Type: application/json" \
  -d "{\"content\":\"$CONTENT\",\"message\":\"Own the infra directory\",\"branch\":\"main\"}" \
  -o /dev/null -w 'add CODEOWNERS: %{http_code}\n'
curl -s -X PATCH "$A/api/v1/repos/ci/platform/branch_protections/main" \
  -H "Content-Type: application/json" -d '{"enable_push":false}' -o /dev/null
curl -s "$A/api/v1/repos/ci/platform/raw/.gitea/CODEOWNERS?ref=main"
```{{exec}}

**`infra/.*` and not `infra/*`, and this one will catch you.** This forge
matches CODEOWNERS paths as **regular expressions**; GitHub matches them as
gitignore-style globs. `infra/*` is a perfectly good glob and a regex that means
"infra" followed by any number of slashes — so on GitHub it works and here it
silently matches nothing.

Nothing warns you. The file parses, the entry looks right, and no reviewer is
ever requested. **Check the behaviour, not the file**, whichever forge you are
on — which is exactly what the rest of this step does.

## A change inside the owned path

```
cd /root/platform
git fetch -q origin && git checkout -q -B feature/infra origin/main
mkdir -p infra
echo 'resource "aws_s3_bucket" "state" {}' >> infra/main.tf
git add -A && git commit -qm "add a bucket"
git push -q origin feature/infra 2>&1 | tail -1
PR=$(curl -s -X POST "$A/api/v1/repos/ci/platform/pulls" \
  -H "Content-Type: application/json" \
  -d '{"head":"feature/infra","base":"main","title":"Add a bucket"}')
NUM=$(echo "$PR" | tr ',' '\n' | grep -o '"number":[0-9]*' | head -1 | cut -d: -f2)
sleep 4
echo "PR $NUM requested reviewers:"
curl -s "$A/api/v1/repos/ci/platform/pulls/$NUM" \
  | grep -o '"requested_reviewers":\[[^]]*\]' | grep -o '"login":"[^"]*"' || echo "(none)"
```{{exec}}

`platform-lead`, asked for by the server, because the change touched a path they
own. Nobody had to know to add them.

## The control that proves it is the path, not the luck

```
cd /root/platform
git checkout -q -B feature/readme origin/main
echo "a docs change" >> README.md
git add -A && git commit -qm "touch an unowned path"
git push -q origin feature/readme 2>&1 | tail -1
PR2=$(curl -s -X POST "$A/api/v1/repos/ci/platform/pulls" \
  -H "Content-Type: application/json" \
  -d '{"head":"feature/readme","base":"main","title":"Docs only"}')
N2=$(echo "$PR2" | tr ',' '\n' | grep -o '"number":[0-9]*' | head -1 | cut -d: -f2)
sleep 4
echo "PR $N2 requested reviewers:"
curl -s "$A/api/v1/repos/ci/platform/pulls/$N2" \
  | grep -o '"requested_reviewers":\[[^]]*\]' | grep -o '"login":"[^"]*"' || echo "(none - README is owned by nobody)"
```{{exec}}

One PR pulls the owner in, the other does not. **Run both.** A rule that fires
on everything is indistinguishable from a rule that fires correctly until the
day you need it not to.

**Done when:** a PR touching `infra/` has `platform-lead` requested, and one
touching only `README.md` does not.
