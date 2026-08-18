# There is no deny rule

This cluster was not built by you. Audit what it already grants:

```
kubectl get clusterrolebindings -o custom-columns=NAME:.metadata.name,ROLE:.roleRef.name,SUBJECTS:.subjects[*].name | grep cluster-admin
```{{exec}}

Three rows. Two of them are supposed to be there:

- **`cluster-admin`** binds the `system:masters` group — that is how your own
  `kubectl` works
- **`kubeadm:cluster-admins`** is how the installer grants administrators access

Leave both alone; deleting either locks you out of your own cluster. The third,
**`legacy-ci-admin`**, binds the `legacy-ci` ServiceAccount in `team-a` to
`cluster-admin`. Confirm what that means:

```
CI=system:serviceaccount:team-a:legacy-ci
kubectl auth can-i "*" "*" --all-namespaces --as $CI
kubectl auth can-i delete nodes -A --as $CI
kubectl auth can-i get secrets -n kube-system --as $CI
```{{exec}}

A CI account that can read every Secret in the cluster and delete nodes. This is
the most common over-grant there is, and it is nearly always there because
something did not work once and this made it work.

## Try to take it back the wrong way

The instinct is to write a rule that restricts it. Try:

```
kubectl apply -f - <<'YAML'
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: team-a
  name: legacy-ci-restricted
rules:
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get"]
YAML
kubectl create rolebinding legacy-ci-restricted -n team-a \
  --role=legacy-ci-restricted --serviceaccount=team-a:legacy-ci

kubectl auth can-i delete nodes -A --as system:serviceaccount:team-a:legacy-ci
```{{exec}}

Still `yes`.

**RBAC is purely additive. There is no deny rule.** A subject can do the union
of everything its bindings grant, so a narrow Role adds a little and takes away
nothing. When an account has too much access the fix is always to find the
extra binding — never to add a denial, because none exists.

This is also why *removing* a binding sometimes changes nothing: another
binding still grants it, and the only way to know is to list every binding that
names the subject.

## Take it back the right way

Remove the grant, and **keep the ServiceAccount**. The identity is not the
problem; the binding is:

```
kubectl delete clusterrolebinding legacy-ci-admin

CI=system:serviceaccount:team-a:legacy-ci
kubectl auth can-i "*" "*" --all-namespaces --as $CI
kubectl auth can-i delete nodes -A --as $CI
kubectl auth can-i get pods -n team-a --as $CI
```{{exec}}

`no`, `no`, `yes`. The account still exists and still holds exactly the small
grant you gave it a minute ago. That is what revoking looks like — the workload
using this account keeps running, with less.

Deleting the ServiceAccount instead would also stop the access, and would be
the wrong move: it breaks whatever was using it, and leaves the binding behind
to attach itself to the next account created with that name.

**Done when:** `legacy-ci` is no longer `cluster-admin`, and the ServiceAccount
still exists.
