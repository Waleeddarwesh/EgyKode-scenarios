A repository is waiting at `/root/shop` with six commits. Somewhere in that
history is an AWS key that somebody committed and then "removed" in the next
commit — which does nothing at all about the commit that still contains it.

**What you will do**

1. **Undo a hard reset** — destroy three commits, then get them back
2. **Restore a deleted branch** — after deleting it with `-D`
3. **Purge a secret from history** — from every commit that ever held it

Nothing here is simulated, and almost nothing you do locally is truly
destructive. That is the point.

```
cd /root/shop && git log --oneline
```{{exec}}
