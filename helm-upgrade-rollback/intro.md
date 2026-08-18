Building a chart is the small half of the job. The other half is upgrading it,
finding out the new version does not start, and getting back to the one that
did — while somebody is watching.

**What you will do**

1. **Install a release** you can then operate on
2. **Upgrade it**, and read the history Helm keeps for you
3. **Break an upgrade deliberately** — and watch Helm undo it without being asked
4. **Roll back to a named revision**, and check what is actually running rather
   than what should be

The third step is the one worth the time. Anyone can deploy; the job is what
happens when a deploy fails at five o'clock.

```
helm version --short
kubectl get namespace demo
```{{exec}}
