# Resolve a real conflict

The colleague raised `PRICE` to 120. Change it on your branch to 150 and rebase
again — this time the same line differs on both sides.

```
cd /root/shop
git switch feature/discount
sed -i 's/^PRICE = .*/PRICE = 150/' app.py
git commit -am "Set price to 150"
```{{exec}}

Now create the conflict deliberately, by rebasing onto a `main` that moved:

```
git switch main
sed -i 's/^PRICE = .*/PRICE = 130/' app.py
git commit -am "Colleague sets price to 130"
git switch feature/discount
git rebase main
```{{exec}}

Git stops. Open `app.py`, read **both** sides, and decide — do not take one
wholesale. Then:

```
git add app.py
git rebase --continue
```

**Done when:** the rebase has finished, no conflict markers remain in the file,
and `PRICE` holds the value you chose.
