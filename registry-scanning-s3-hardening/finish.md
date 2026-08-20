# Done

A registry that scans without being asked, a policy that prunes without being
asked, buckets that were never open, and a state file recovered from a delete.

**What you can now do**

- Read scan findings from a registry and say what severity filter a gate should
  use — and why an end-of-life base image reports almost nothing under one
- State how many images a retention policy keeps, which is the question nobody
  can answer about their own registry until the day they need to roll back
- Set all four public-access-block settings and say what each one stops,
  because two of the four is how a bucket ends up public anyway
- Write a bucket policy that names both the bucket ARN and `/*`, and explain
  why one without the other half-works
- Recover a deleted object, and explain that a delete on a versioned bucket
  writes a marker rather than removing anything

**The two habits worth taking**

*Test a deny by making the request it should refuse.* You wrote a policy here
that denies every plaintext request, on an endpoint where every request is
plaintext, and it denied nothing. You only found that out by trying. On a real
account the equivalent check is one `curl http://` that must come back
`AccessDenied` — two seconds, and it is the difference between a policy and a
belief.

*A scan that found nothing and a scan that never ran look identical.* Both
produce an empty findings list and a green tick. The question is never "did it
pass" but "did it run, and against what".

**Where this differs from ECR**

The concepts map one to one and the wiring does not:

| Here | On ECR |
| --- | --- |
| `extensions.search.cve` | `imageScanningConfiguration { scan_on_push = true }` |
| `CVEListForImage` over GraphQL | `aws ecr describe-image-scan-findings` |
| `retention.keepTags.mostRecentlyPushedCount` | `countType = "imageCountMoreThan"` |
| `deleteUntagged: true`, immediate | `tagStatus = "untagged"`, `countUnit = "days"` |

That last row is a real difference, not just syntax. ECR's window exists so a
mistaken overwrite is recoverable; this registry drops an orphaned manifest at
once. Knowing which one you are on decides whether a bad push is a mistake or
an incident.

**Next**

The image you scanned should never reach the registry if the scan finds
something serious. Putting that gate in a pipeline — so a vulnerable image
fails the build instead of being published and reported on — is the CI lab.
