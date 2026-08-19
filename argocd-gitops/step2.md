You have not deployed anything yet — you applied one Application and Argo CD
did the rest. Now change what is running, without touching the cluster.

## Commit a new image tag

```
cd ~/app
sed -i 's|nginx:1.27-alpine|nginx:1.29-alpine|' manifests/web.yaml
grep image: manifests/web.yaml
```{{exec}}

```
git commit -am "web: nginx 1.29"
git push origin main
```{{exec}}

That is the deployment. There is nothing else to run.

## Now wait, and watch

```
kubectl -n argocd get application web-app -w
```{{exec}}

`Synced` → `OutOfSync` → `Synced`, with `Healthy` → `Progressing` → `Healthy`
underneath it. Press `Ctrl+C` when it settles.

**Give it up to a minute.** Argo CD polls Git; nothing pushed to it. This
environment sets `timeout.reconciliation: 30s`, and push to running Pod was
measured here at 26 to 50 seconds. On the 180s default it was 230 seconds —
nearly four minutes for a one-line change.

Production does not wait for either: the Git host sends a webhook to
`/api/webhook` and the sync starts within a second. Polling is the fallback,
not the mechanism.

Note the asymmetry, because step 3 depends on it: **changes in Git are polled,
changes in the cluster are watched.** One takes minutes, the other is instant.

## Verify against the Pod, not the manifest

The manifest says what you asked for. The Pod says what happened:

```
kubectl -n web get pods -l app=web -o jsonpath='{.items[*].spec.containers[*].image}'; echo
```{{exec}}

Checking the manifest instead would only prove you can read your own commit.

## The deployment record

```
kubectl -n argocd get application web-app -o custom-columns='ID:.status.history[*].id,REVISION:.status.history[*].revision'
```{{exec}}

Every sync, against the commit that caused it. This is the deployment record —
there is no separate one, and it cannot drift from reality, because it *is*
what caused reality.
