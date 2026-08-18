There are three directories of manifests — dev, staging and prod. They started
identical and are not any more. Nobody can say what differs except by diffing
them, and the diff is four hundred lines because the namespace and the image tag
appear in every file.

A chart replaces all three with one template set and three values files.

**What you will do**

1. **Build a small chart and render it** — catching mistakes before the cluster
   is involved, and learning what `lint` will not catch for you
2. **Install it twice**, into two namespaces with different values and no edited
   templates
3. **Make a config change actually reach the Pods** — with the one annotation
   that separates a chart that works from a chart that looks like it works

```
helm version --short
kubectl get namespace dev staging
```{{exec}}
