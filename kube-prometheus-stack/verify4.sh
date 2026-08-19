#!/bin/bash
# Criterion 4: metrics survive a Prometheus Pod restart.
#
# The evidence has to be that history from BEFORE the restart is still
# queryable. Checking that Prometheus is running after a restart proves
# nothing - an emptyDir Prometheus restarts perfectly and comes back empty,
# which is precisely the bug.
NS=monitoring
PROM="http://kps-kube-prometheus-stack-prometheus:9090"

q() {
  kubectl run vq$RANDOM --rm -i --restart=Never --image=curlimages/curl:8.10.1 -n "$NS" \
    --command -- curl -s --max-time 20 "$PROM/api/v1/$1" 2>/dev/null \
    | sed 's/}{"status"/}\n{"status"/g' | head -1
  # The sed is not cosmetic. `kubectl run -i` emits the Pod's stdout twice,
  # concatenated on one line as ...}}{"status":..., so a plain head -1 keeps
  # both. Every numeric extraction then saw "14\n14", failed the digits-only
  # guard, and silently read as 0 - a verifier reporting "0 targets are up"
  # about a cluster scraping fourteen of them.
}

# The numeric value of the first result, or empty. Kept in one place because
# every ad-hoc variant of this got the quoting or the anchoring subtly wrong.
val() {
  echo "$1" | grep -o '"value":\[[^]]*\]' | head -1 | sed 's/.*,"//; s/"\]*$//'
}
int() { v=$(val "$1"); v=${v%%.*}; case "$v" in ''|*[!0-9]*) echo 0 ;; *) echo "$v" ;; esac; }

# Storage must be a PVC. This is the cause, and naming it here means a learner
# who left the default gets told why rather than just "no".
CLAIM=$(kubectl get statefulset prometheus-kps-kube-prometheus-stack-prometheus -n "$NS" \
  -o jsonpath='{.spec.volumeClaimTemplates[0].metadata.name}' 2>/dev/null)
if [ -z "$CLAIM" ]; then
  echo "FAIL: the Prometheus StatefulSet has no volumeClaimTemplate"
  echo "      With no storageSpec the chart gives Prometheus an emptyDir,"
  echo "      which dies with the Pod. Every graph resets at each restart and"
  echo "      nothing reports an error."
  exit 1
fi

BOUND=$(kubectl get pvc -n "$NS" --no-headers 2>/dev/null | grep -c Bound)
case "$BOUND" in ''|*[!0-9]*) BOUND=0 ;; esac
[ "$BOUND" -ge 1 ] || {
  echo "FAIL: no bound PersistentVolumeClaim in $NS"
  echo "      A Pending PVC usually means no default StorageClass."
  exit 1; }

# The Pod must have been replaced at least once, or persistence has not been
# demonstrated - only configured. This is the presence half of the check.
RESTARTED=$(kubectl get pod prometheus-kps-kube-prometheus-stack-prometheus-0 -n "$NS" \
  -o jsonpath='{.metadata.creationTimestamp}' 2>/dev/null)
STS_AGE=$(kubectl get statefulset prometheus-kps-kube-prometheus-stack-prometheus -n "$NS" \
  -o jsonpath='{.metadata.creationTimestamp}' 2>/dev/null)
if [ -n "$RESTARTED" ] && [ "$RESTARTED" = "$STS_AGE" ]; then
  echo "FAIL: the Prometheus Pod is the original one"
  echo "      Delete it and let the StatefulSet replace it, then re-check."
  exit 1
fi

for i in $(seq 1 30); do
  R=$(q "query?query=up%7Bnamespace%3D%22shop%22%7D")
  echo "$R" | grep -q '"value"' && break
  sleep 10
done
echo "$R" | grep -q '"value"' || {
  echo "FAIL: Prometheus is not answering after the restart"; exit 1; }

# History across the restart, proven by asking for a moment that predates this
# process.
#
# The first version of this compared a sample count against uptime divided by
# the scrape interval. That only holds for a minute or two after the restart:
# leave Prometheus running for twenty minutes and it can honestly gather as
# many samples as the ceiling allowed, so the check started failing a correct
# answer. Wall-clock heuristics decay; a timestamp does not.
#
# Prometheus can answer a query "as of" any instant. Ask it about a moment
# safely before this process started: only data read off the volume can be
# there, because this process was not running to scrape it.
START=$(int "$(q 'query?query=max(process_start_time_seconds%7Bjob%3D%22kps-kube-prometheus-stack-prometheus%22%7D)')")
if [ "$START" -le 0 ]; then
  echo "FAIL: cannot read Prometheus's own start time"; exit 1
fi

BEFORE=$(( START - 120 ))
# count(up), not the application's metric. The app only starts being scraped
# when the learner fixes its ServiceMonitor in step 2, which can be moments
# before they delete the Pod here - so there may legitimately be no app history
# two minutes back. The cluster's own targets have been scraped since the
# original install, so they are the ones that prove the volume kept anything.
PAST=$(q "query?query=count(up)&time=$BEFORE")

if ! echo "$PAST" | grep -q '"value"'; then
  echo "FAIL: Prometheus holds no data from before it started"
  echo ""
  echo "      Asked for count(up) at $BEFORE - two minutes before"
  echo "      this Prometheus process began - and got nothing back. Everything"
  echo "      it holds was gathered after the restart, so the history did not"
  echo "      survive."
  echo ""
  echo "      That is exactly what an emptyDir looks like: the Pod restarts"
  echo "      cleanly, the graphs come back, and the past is silently gone."
  echo "      If the PVC is bound, check the application was being scraped for"
  echo "      a few minutes BEFORE you deleted the Pod - there has to be some"
  echo "      history for the volume to keep."
  exit 1
fi

echo "PASS - data from before this Prometheus process started is still queryable: the volume kept it"
exit 0
