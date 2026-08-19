Logs now outlive the containers that wrote them.

**What you proved**

- One DaemonSet collected every namespace on the node without being told what
  was running in them
- The selector is what makes a LogQL query affordable; the filter only reduces
  what the selector already read
- Loki held the cause of a crash that `kubectl logs --previous` could no longer
  reach, and would have held it across a reschedule onto another node

**The failure worth remembering**

An agent installed before its backend answers drops what it collected and then
stops discovering new Pods. Everything stays green. The stack reports healthy
and holds nothing, and the first symptom is a query that returns no rows — which
reads as a query problem for as long as you let it.

**What was real here, and what was not**

The collection, the labels, the storage and every LogQL query are exactly what
they are in production. Two things were shrunk: Loki ran as a single binary on
an `emptyDir` rather than as a set of components on object storage, and Grafana
was not installed — you called the same HTTP API its query box calls, which is
worth having done once.

Retention was set to seven days. On a real cluster that number is a bill, and
the default is no limit at all.
