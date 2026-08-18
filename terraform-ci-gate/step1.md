# The cheap checks, first

A small configuration to run the gate against. It manages a file rather than a
cloud resource, so every check below behaves exactly as it would on real
infrastructure without costing anything or needing credentials:

```
mkdir -p ~/infra && cd ~/infra
cat > main.tf <<'TF'
terraform {
  required_version = ">= 1.6"
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

variable "log_level" {
  type    = string
  default = "info"
}

resource "local_file" "app_config" {
  filename        = "${path.module}/out/app.conf"
  content         = "log_level=${var.log_level}\n"
  file_permission = "0644"
}
TF
terraform init -input=false | tail -2
```{{exec}}

## fmt

```
cd ~/infra
terraform fmt -check -recursive
echo "exit code: $?"
```{{exec}}

Exit `0` — nothing to reformat. Now add a file the way people actually type it
at half past six:

```
cd ~/infra
cat > tags.tf <<'TF'
variable "common_tags" {
  type=map(string)
    default={ Owner="platform", Env="dev" }
}
TF
terraform fmt -check -recursive
echo "exit code: $?"
```{{exec}}

It names `tags.tf` and exits **3**. Note that it is not exit 1 — a gate written
as `if [ $? -eq 1 ]` would let this straight through, which is why the shell
scripts later in this scenario test for *non-zero* rather than for a number.

**`-check` reports without rewriting.** Leave it off and `fmt` silently edits
your files, which is what you want on a laptop and never what you want in CI —
a job that rewrites the code it is checking has nothing to fail about.

```
cd ~/infra
terraform fmt -recursive
terraform fmt -check -recursive && echo "clean"
cat tags.tf
```{{exec}}

## validate

```
cd ~/infra
terraform validate
```{{exec}}

`Success! The configuration is valid.`

**`validate` needs no credentials and no state.** In CI it runs as
`terraform init -backend=false` followed by `validate`, which means it can run
on a pull request from a fork — nothing it does touches your account.

Now break it in a way `fmt` cannot see:

```
cd ~/infra
cp main.tf /tmp/main.tf.bak
sed -i 's/content         = "log_level=${var.log_level}\\n"/content         = "log_level=${var.log_levl}\\n"/' main.tf
terraform validate
echo "exit code: $?"
```{{exec}}

```
Error: Reference to undeclared input variable
```

A single missing character in a variable name. Perfectly formatted, completely
broken, and caught in under a second without a cloud account.

```
cd ~/infra && cp /tmp/main.tf.bak main.tf && terraform validate
```{{exec}}

**Done when:** `terraform fmt -check -recursive` and `terraform validate` both
pass.
