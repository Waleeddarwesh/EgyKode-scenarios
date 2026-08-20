# Two storage services that get grouped together and behave nothing alike

Images are pushed with the tag `latest`, so nobody can say which commit is in
production. Nothing scans them. The registry has eleven months of untagged
layers nobody can delete safely because nobody knows what references them.

The buckets were created by hand, and one of them is public.

You will fix both halves, and find out which of your fixes this environment
actually enforces.

## What stands in for what

The registry is **zot**, a real OCI registry, not ECR — because ECR is not in
the free LocalStack image (`API for service 'ecr' not yet implemented or pro
feature`).

That is a substitution rather than a simulation, and the difference matters:
the scans are Trivy's, the CVEs are real ones with real severities, and the
retention policy genuinely deletes tags off the disk. What differs is where you
write the policy — a registry config file instead of an ECR lifecycle policy —
and each step shows the ECR form of the same rule beside it.

**S3 is genuinely S3.** Versioning, delete markers and recovery all behave as
they do on a real account.

## One thing it does not enforce, and why that is the lesson

LocalStack stores bucket policies and does not evaluate them. So the TLS-only
policy you write in step 3 will be accepted, will read back correctly, and will
refuse nothing — on an endpoint where *every* request is plaintext and the
policy says to deny them all.

That is not a flaw to work around. It is the most useful thing in this
scenario, because **configuration that is accepted is not configuration that is
enforced**, and nothing tells you which one you have. Step 3 makes you look.

## What you will end up with

- An image scanned because it arrived, not because a pipeline remembered
- A retention policy you can state the number for — three
- Buckets closed four different ways, and the knowledge of why two is not enough
- A deleted state file, recovered

Setup pulls a registry and LocalStack, about a minute and a half. Step 1 waits.
