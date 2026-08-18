# A release to operate

`helm create` scaffolds a working chart — a Deployment, a Service, a
ServiceAccount and a values file:

```
[ -d demo-chart ] || helm create demo-chart
ls demo-chart demo-chart/templates
```{{exec}}

Install it. `--wait` holds the command open until the resources are actually
ready rather than merely accepted:

```
helm install demo ./demo-chart -n demo --set image.tag=1.27-alpine --wait --timeout 180s
helm list -n demo
kubectl get pods -n demo
```{{exec}}

One replica, `STATUS: deployed`, `REVISION: 1`.

## Where that revision lives

```
kubectl get secret -n demo -l owner=helm
```{{exec}}

`sh.helm.release.v1.demo.v1`. **Helm stores each revision's rendered manifests
and values in a Secret in the release namespace.** Nothing lives on your
laptop, and nothing needs re-fetching to go back — which is why a rollback
takes a second rather than a rebuild.

It also means the release history is a cluster object with the usual
consequences: delete the namespace and the history goes with it, and anyone who
can read Secrets in that namespace can read every value you passed, including
the ones you would rather they did not.

**Done when:** the `demo` release is installed and reports `deployed` at
revision 1.
