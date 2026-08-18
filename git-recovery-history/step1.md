# Undo a hard reset

Destroy three commits on purpose:

```
cd /root/shop
git reset --hard HEAD~3
git log --oneline
```{{exec}}

Three commits gone. They are not deleted — nothing in Git is deleted until it
is garbage collected, and that is weeks away.

`git reflog` is the repository's own undo history: every position `HEAD` has
held, including the one you just left.

```
git reflog
```{{exec}}

Find the entry from **before** the reset and move the branch back to it. Either
of these works:

```
git reset --hard HEAD@{1}
```{{exec}}

**You should see** `git log --oneline` back to six commits.
