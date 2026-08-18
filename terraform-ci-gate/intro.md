Terraform runs from somebody's laptop. Reviews read the HCL rather than the
plan, so nobody notices the `-/+` that will recreate the database until it has
been recreated.

This is the gate that goes in front of the apply:

```text
fmt  ->  validate  ->  tflint  ->  security scan  ->  plan  ->  review  ->  apply
```

**Cheapest first.** `fmt` takes a second, a scan takes twenty, and `plan` calls
the cloud. Failing early means the expensive checks only run on changes that
have earned them.

**What you will do**

1. **Run the two checks that need no credentials** — and see what each one is
   blind to
2. **Add the two that catch what they miss** — proving each with a change that
   should fail
3. **Apply a saved plan** — and watch it ignore a config edit made after the
   review
4. **Chain it into one gate**, then catch drift the way a scheduled run does

```
terraform version
tflint --version
trivy --version
```{{exec}}
