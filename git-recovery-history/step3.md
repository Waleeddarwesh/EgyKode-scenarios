# Purge a secret from history

An AWS key was committed, then "removed" in the next commit. Prove that did
nothing:

```
cd /root/shop
git log --oneline -- .env
git log -p --all -S 'wJalrXUtnFEMIK7MDENG' --oneline | head -5
```{{exec}}

The file is gone from the working tree and the value is still in history.
Anyone who clones this repository has the key.

Rewrite every commit that contains it:

```
git filter-branch --force --index-filter \
  'git rm --cached --ignore-unmatch .env' \
  --prune-empty -- --all
```{{exec}}

`filter-branch` leaves the originals behind in `refs/original/` as a safety
net — so the key is still reachable until you drop them:

```
rm -rf .git/refs/original
git reflog expire --expire=now --all
git gc --prune=now --aggressive
```{{exec}}

**You should see** the search return nothing at all.

```
git log -p --all -S 'wJalrXUtnFEMIK7MDENG' --oneline
```{{exec}}
