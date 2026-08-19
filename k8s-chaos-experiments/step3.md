# The experiment record

Two experiments, two numbers, and one of them changes how the platform should be
built. That only counts if it is written down.

```
cd /root/chaos
cat >> experiments.md <<'MD_EOF'

## Experiment 3 — kill the container, not the Pod

**Hypothesis:** killing the process inside a container restarts that container
in place. The Pod keeps its name and IP, `RESTARTS` increases, and the Service
never notices because the Pod object never went away.

**Result:** (filled in after)
MD_EOF
POD=$(kubectl -n chaos get pod -l app=web -o jsonpath='{.items[0].metadata.name}')
IP_BEFORE=$(kubectl -n chaos get pod $POD -o jsonpath='{.status.podIP}')
echo "before: $POD at $IP_BEFORE"
: > /tmp/probe.log
sleep 3
kubectl -n chaos exec $POD -- kill 1
sleep 12
kubectl -n chaos get pod $POD
echo "ip now: $(kubectl -n chaos get pod $POD -o jsonpath='{.status.podIP}')"
echo "failed: $(grep -vc 200 /tmp/probe.log) of $(wc -l < /tmp/probe.log)"
```{{exec}}

Same name, same IP, `RESTARTS` incremented. **A container restart is not a Pod
replacement** — the kubelet restarts the process inside the existing Pod, so
nothing is rescheduled and no address changes.

```
cd /root/chaos
sed -i "0,/\*\*Result:\*\* (filled in after)/s//**Result:** Hypothesis held. Container restarted in place, same Pod name and IP, RESTARTS incremented./" experiments.md
cat experiments.md
```{{exec}}

## What the log is for

Read it back. Three hypotheses, three results, and the value is concentrated in
the one that was uncomfortable:

| Experiment | Recovery | Who recovers it |
| --- | --- | --- |
| Kill a container | seconds, in place | kubelet |
| Kill a Pod | seconds, rescheduled | ReplicaSet |
| Delete the Deployment | **as long as a human takes** | nobody |

**The pattern is that each layer is protected by the one above it, and the top
layer is not protected at all.** That is not a Kubernetes flaw — it is the
reason continuous reconciliation exists. A GitOps controller watching the
Deployment turns the third row into the second.

## Why the hypothesis has to come first

Writing it afterwards produces a description, not a test. You cannot be
surprised by a result you have already seen, and the surprises are the entire
return on the exercise.

The discipline is four steps:

1. **State the steady behaviour** — measurably, before touching anything
2. **Write what you expect**, precisely enough to be contradicted
3. **Inject the smallest failure** that tests it
4. **Record what actually happened**, especially when it disagrees

You met step 1 the hard way in the first experiment: the probe's opening `000`s
were the measurement starting before the system was steady, and counting them
would have disproved a correct hypothesis. **An experiment that measures its own
setup produces a fault that does not exist** — which is worse than no experiment,
because somebody will go and look for it.

**Done when:** the log holds three hypotheses and three results, and the last
experiment shows a restart in place.
