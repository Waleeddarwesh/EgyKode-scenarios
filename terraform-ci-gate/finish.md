# Done

- **Cheapest first.** `fmt` is a second, a scan is twenty, `plan` calls the
  cloud. Ordering the gate this way means the expensive checks only run on
  changes that have earned them — and you saw the gate stop at `tflint` without
  ever reaching the plan
- **Each check is blind to what the next one sees.** `fmt` passed a broken
  variable reference, `validate` passed a variable nobody reads, `tflint` had no
  opinion about SSH open to the internet, and none of them are redundant
- **`terraform fmt -check` exits 3**, not 1. Test for non-zero
- **`--exit-code 1` is what makes a scanner a gate.** Without it the job prints
  warnings, goes green, and stops being read by the second week
- **`validate` and a config scan need no credentials**, which is why they can run
  on a pull request from a fork before anything else
- **Apply the saved plan.** You watched a config edit made after the plan get
  ignored — the artifact is the change, frozen between approval and execution
- **`plan -detailed-exitcode` returns 2 for pending changes.** That single number
  is a drift check, run weekly, that tells you on a Monday instead of during an
  incident

The scan finding worth remembering: `sse_algorithm = "aws:kms"` alone did not
satisfy it. The rule asks for a **customer managed** key, because encryption you
cannot rotate, revoke, or audit access to is not really yours.

---

## Where this fits

**Phase: Infrastructure as Code** — part of [Build the Production Platform](https://egykode.com/en/labs/).

Every Terraform lab after this one writes HCL that this gate would check. The
remote-state lab adds the backend the plan reads from; the modules lab adds the
directories `-recursive` walks. Put the gate in first and the rest of the path
is a series of changes you can review, apply exactly, and detect the drift of —
rather than a directory somebody runs `apply` in from a laptop.
