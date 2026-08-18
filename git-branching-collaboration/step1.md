# Branch and rebase

Create a feature branch, change the discount logic, and rebase it onto `main`.

```
cd /root/shop
git switch -c feature/discount
```{{exec}}

Add a discount function:

```
cat >> app.py <<'PY'

def discounted(qty, pct):
    return total(qty) * (1 - pct / 100)
PY
git commit -am "Add discount"
```{{exec}}

Now rebase onto `main` so your work sits on top of the colleague's commit
rather than beside it:

```
git rebase main
```{{exec}}

**Done when:** `feature/discount` exists and its history is linear on top of
`main` — `git log --oneline --graph` shows one line, not a fork.
