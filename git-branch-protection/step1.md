# A push the server refuses

Wait for the forge, then confirm you can push to `main` right now:

```
until curl -s -o /dev/null --max-time 5 http://localhost:3000/ 2>/dev/null; do sleep 3; done
export A="http://ci:CiPassw0rd!@localhost:3000"
cd /root/platform
echo "before protection" >> README.md
git add -A && git commit -qm "a direct push to main"
git push origin main 2>&1 | tail -2
```{{exec}}

It went straight in. On a repository anybody can push to, `main` is whatever
the last person did, and there is no point at which a second pair of eyes could
have looked.

## Protect the branch

```
curl -s -X POST "$A/api/v1/repos/ci/platform/branch_protections" \
  -H "Content-Type: application/json" \
  -d '{"branch_name":"main","enable_push":false}' \
  -o /dev/null -w 'protect main: %{http_code}\n'
curl -s "$A/api/v1/repos/ci/platform/branch_protections" \
  | tr ',' '\n' | grep -E '"branch_name"|"enable_push"'
```{{exec}}

## Try again

```
cd /root/platform
echo "after protection" >> README.md
git add -A && git commit -qm "a direct push that should not land"
git push origin main
echo "git push exit code: $?"
```{{exec}}

```
! [remote rejected] main -> main (pre-receive hook declined)
```

**Read where that came from.** `remote:` means the server said it. The rejection
is not your client being polite — the push travelled, the server ran its
pre-receive hook, and the hook refused. That is the only kind of branch
protection that is worth anything: a rule enforced where the data lands, not in
a convention people agree to follow.

A `.git/hooks/pre-commit` on your laptop is the opposite. It is advisory, it is
per-clone, and `--no-verify` skips it.

## Your commit is not lost

```
cd /root/platform
git log --oneline -2
git status -sb | head -2
```{{exec}}

Still there, still local, and `main` on the server is unchanged. **A rejected
push changes nothing on either side** — which is why this is a safe thing to
discover by trying, and why the fix is to move the commit onto a branch rather
than to recover anything.

```
cd /root/platform
git branch -f feature/first-change
git reset -q --hard origin/main
git checkout -q feature/first-change
git log --oneline -1
```{{exec}}

**Done when:** `main` is protected and a direct push to it is rejected by the
server.
