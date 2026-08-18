A repository is waiting at `/root/shop`. It has two commits on `main` — the
second is a colleague's change to the same line you are about to touch, so the
conflict you hit later is a real one rather than one staged against yourself.

**What you will do**

1. **Branch and rebase** — put your work on top of theirs, not beside it
2. **Resolve a real conflict** — by reading both sides, not taking one wholesale
3. **Recover a lost commit** — destroy work deliberately, then get it back

Everything here is a real repository. Nothing is simulated.

Start by seeing what you have inherited:

```
cd /root/shop && git log --oneline
```{{exec}}
