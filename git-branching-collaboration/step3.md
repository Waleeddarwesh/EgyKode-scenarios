# Recover with the reflog

Destroy your work, then get it back.

```
cd /root/shop
git switch feature/discount
git log --oneline
git reset --hard HEAD~2
git log --oneline
```{{exec}}

Two commits are gone. They are not deleted — nothing in Git is deleted until it
is garbage collected. The reflog still knows where the branch pointed:

```
git reflog
```{{exec}}

Find the entry from before the reset and return the branch to it:

```
git reset --hard <the-sha-from-reflog>
```

**Done when:** `feature/discount` again contains the discount function and your
price change.
