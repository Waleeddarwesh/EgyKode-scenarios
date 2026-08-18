# Done

- **`version` and `appVersion` are different questions.** The chart's version
  and the application's version drift apart immediately, and conflating them is
  how "we deployed 1.4.2" becomes an argument
- **The `fullname` helper is not ceremony.** It is what lets one chart be
  installed twice without collision, and what makes renaming a release a
  one-line change
- **Selector labels are a subset of labels**, because a Deployment's selector is
  immutable. Put `appVersion` in it and the next version bump cannot be upgraded
  at all
- **`lint`, `template`, and `--dry-run=server` all pass a chart the API server
  will reject.** Only `helm template | kubectl apply --dry-run=server` actually
  validates the output. That is the line for CI
- **`checksum/config` is the idiom to memorise.** Without it, a config change is
  a deploy that reports success and changes nothing until some unrelated restart
- **Wrap `replicas` in `if not .Values.autoscaling.enabled`** the day an HPA
  appears, or the chart and the autoscaler will fight on every upgrade

The config-and-secrets scenario showed that `envFrom` values are read once and
need the Pods replaced. This is the same fact, solved properly: the chart makes
the Pod template depend on the config, so the rollout is automatic rather than
something a human has to remember at the end of a long day.

---

## Where this fits

**Phase: Kubernetes** — part of [Build the Production Platform](https://egykode.com/en/labs/).

This chart is the unit Argo CD reconciles later in the path. Once a controller
is applying the rendered output on every commit, a missing `checksum/config`
stops being an inconvenience and becomes a class of change that silently never
takes effect — no human is watching the deploy to notice the Pods did not
restart.
