# Done

- **Three states, and the middle one is the point.** `inactive`, `pending`,
  `firing` — and nothing is notified until the last. You watched the alert sit
  pending for the full minute before it fired
- **`for:` is a statement about how long a problem must persist to be worth a
  human.** Removing it made the alert fire on a single evaluation and resolve
  within a minute, which is the definition of pager noise. It is not a delay to
  be minimised
- **Reload rather than restart.** A restart loses every alert's pending state,
  so a system that restarts Prometheus more often than the `for:` duration can
  suppress an alert indefinitely
- **The expression is the alert.** Run it by hand before it goes in a rule file;
  everything else decides when it notifies and what it says
- **Labels are identity, annotations are text.** `severity` and `service` route;
  a rate value in a label would make every fire a different alert
- **`{{ $value }}` in the summary** is the difference between a notification that
  reports the problem and one that reads identically every time
- **An alert with no runbook asks somebody to invent a procedure while tired**
- **Rate, Errors, Duration.** A dashboard without those three is not the one
  anyone opens during an incident — and a latency *average* hides the slow
  requests inside the fast ones, which is why the panel is p95

---

## Where this fits

**Phase: Observability** — part of [Build the Production Platform](https://egykode.com/en/labs/).

The platform's alerts are the last thing built and the first thing that decides
whether anyone trusts it. An alert nobody can act on gets muted, and a muted
alert is indistinguishable from one that was never written — which is how a
platform with full monitoring coverage still finds out about outages from a
user.
