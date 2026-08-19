# Prove the gate stops the build

A gate you have not seen fail is a gate you cannot trust. Break it on purpose.

## Choose the vulnerable base carefully

The instinct is to reach for an end-of-life distribution. **That does not work
here, and the reason is worth more than the exercise.** Check for yourself:

```
docker pull -q ubuntu:18.04 >/dev/null
echo "ubuntu:18.04 (end of life):"
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v trivy-cache:/root/.cache \
  aquasec/trivy:latest image --severity HIGH,CRITICAL --ignore-unfixed --scanners vuln \
  --quiet ubuntu:18.04 2>/dev/null | tail -5
```{{exec}}

Nothing. An end-of-life distribution ships **no fixes**, so nearly every
vulnerability it carries is `status: unfixed` — and `--ignore-unfixed` is
exactly the flag that discards those. The most neglected image on the machine is
the one this gate says least about.

Use a **frozen point release of a distribution that is still maintained**:

```
echo "debian:12.5-slim (a snapshot Debian has since shipped fixes for):"
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v trivy-cache:/root/.cache \
  aquasec/trivy:latest image --severity HIGH,CRITICAL --ignore-unfixed --scanners vuln \
  --quiet debian:12.5-slim 2>/dev/null | tail -6
```{{exec}}

Findings, because Debian 12 *is* still shipping fixes — the snapshot simply
never rebuilt to include them. That gap widens every month.

## Break the image

```
cd /root/app
sed -i 's|^FROM debian:12-slim|FROM debian:12.5-slim|' Dockerfile
head -1 Dockerfile
git commit -aqm "Pin the base image to a snapshot"
git log --oneline -1
```{{exec}}

## Run it, and watch the push never happen

```
cd /root/ci
# The build number is claimed before the trigger and waited on by number.
# lastBuild still points at the previous run while this one is queued, and
# Jenkins coalesces identical queued triggers - so a loop reading a stale
# final result can skip a build entirely without ever saying so.
N=$(curl -s -u admin:adminpass http://localhost:8080/job/platform-image/api/json | jq -r '.nextBuildNumber')
CRUMB=$(curl -s -c /tmp/ck -u admin:adminpass http://localhost:8080/crumbIssuer/api/json | jq -r '.crumbRequestField + ": " + .crumb')
curl -s -o /dev/null -w 'start build: %{http_code}\n' -b /tmp/ck -u admin:adminpass \
  -H "$CRUMB" -X POST "http://localhost:8080/job/platform-image/build"
for i in $(seq 1 90); do
  R=$(curl -s -u admin:adminpass "http://localhost:8080/job/platform-image/$N/api/json" 2>/dev/null | jq -r '.result // "RUNNING"' 2>/dev/null)
  case "$R" in SUCCESS|FAILURE|ABORTED|UNSTABLE) break ;; esac
  printf "."
  sleep 5
done
echo
echo "build #$N result: $R"
```{{exec}}

`FAILURE`. Now confirm *where* it stopped — the distinction between a gate and
a report is entirely in whether the stage after it ran:

```
curl -s -u admin:adminpass "http://localhost:8080/job/platform-image/$N/consoleText" > /tmp/gate.log
grep -E 'Total: |skipped due to earlier|ERROR: script returned' /tmp/gate.log | head
echo "--- did the push actually authenticate? ---"
echo "Login Succeeded lines: $(grep -c 'Login Succeeded' /tmp/gate.log)"
```{{exec}}

`Total: 20 (HIGH: 18, CRITICAL: 2)`, then `Stage "Push" skipped due to earlier
failure(s)`, and **zero** `Login Succeeded` lines.

Read that skip line carefully, because the stage list is misleading here. A
skipped stage still appears in the pipeline output — Jenkins enters the block
and then declines to run its steps, so grepping for stage names finds `Push`
in a build where the push never happened. The evidence that it did not run is
the skip line and the absent login, not the absence of the name.

```
SHA=$(cd /root/app && git rev-parse --short=7 HEAD)
echo "the broken commit is $SHA"
curl -s -u ci:ci-lab-password http://localhost:5000/v2/platform/api/tags/list
```{{exec}}

**The vulnerable commit is not in the registry.** That is the whole point:
`--exit-code 1` turns a report into a gate, and a scan placed *after* the push
would have published this image before saying anything about it.

## Fix it

```
cd /root/app
sed -i 's|^FROM debian:12.5-slim|FROM debian:12-slim|' Dockerfile
git commit -aqm "Rebuild on the current base image"
cd /root/ci
# The build number is claimed before the trigger and waited on by number.
# lastBuild still points at the previous run while this one is queued, and
# Jenkins coalesces identical queued triggers - so a loop reading a stale
# final result can skip a build entirely without ever saying so.
N=$(curl -s -u admin:adminpass http://localhost:8080/job/platform-image/api/json | jq -r '.nextBuildNumber')
CRUMB=$(curl -s -c /tmp/ck -u admin:adminpass http://localhost:8080/crumbIssuer/api/json | jq -r '.crumbRequestField + ": " + .crumb')
curl -s -o /dev/null -w 'start build: %{http_code}\n' -b /tmp/ck -u admin:adminpass \
  -H "$CRUMB" -X POST "http://localhost:8080/job/platform-image/build"
for i in $(seq 1 90); do
  R=$(curl -s -u admin:adminpass "http://localhost:8080/job/platform-image/$N/api/json" 2>/dev/null | jq -r '.result // "RUNNING"' 2>/dev/null)
  case "$R" in SUCCESS|FAILURE|ABORTED|UNSTABLE) break ;; esac
  printf "."
  sleep 5
done
echo
echo "build #$N result: $R"
curl -s -u ci:ci-lab-password http://localhost:5000/v2/platform/api/tags/list
```{{exec}}

Same distribution, same packages, same Dockerfile but for one tag — and the
difference is that one of them is rebuilt as fixes land and the other is a
photograph of a machine from a particular Tuesday.

**A base image is a frozen point in time. Nothing about it improves on its own.**
`docker build --pull` on a schedule is not housekeeping; it is the only thing
that moves an image forward.

**Done when:** the snapshot build failed at the scan with nothing pushed, and
the rebuilt one passed.
