# The second run should say nothing

Run exactly the same playbook again:

```
cd /root/ansible
export LANG=C.UTF-8 LC_ALL=C.UTF-8
ansible-playbook site.yml | tail -12
```{{exec}}

`changed=0`. Nothing was installed, nothing was restarted, and Jenkins never
stopped serving. **That is the property that makes a playbook safe to run on a
schedule**, and it is not automatic — you get it because every task above
declares a *state* rather than an action.

## Why these tasks are idempotent and a shell script is not

```
cd /root/ansible
grep -n "state:" roles/*/tasks/main.yml
```{{exec}}

`state: present`, `state: started`. Each task asks "is this so?" and acts only
if it is not. Compare the shell version of the same work:

```
echo 'apt-get install -y jenkins        # runs the installer every time'
echo 'systemctl start jenkins           # a restart, even when it is running'
echo 'echo "..." >> /etc/some.conf      # appends a duplicate line on every run'
```{{exec}}

The third is the one that bites: an `>>` in a provisioning script silently
grows a config file every run until something refuses to parse it, months
later.

## The two tasks that break idempotency most often

Run this to see the difference between a task that reports honestly and one
that lies:

```
cd /root/ansible
cat > /tmp/honesty.yml <<'YAML'
- hosts: build
  become: false
  tasks:
    - name: A command that always reports changed
      ansible.builtin.command: echo hello

    - name: The same command, told the truth about itself
      ansible.builtin.command: echo hello
      changed_when: false
YAML
ansible-playbook /tmp/honesty.yml | tail -12
```{{exec}}

`command` and `shell` cannot know whether they changed anything, so Ansible
assumes they did. A playbook full of them reports `changed=` a number on every
run forever, and once that is normal nobody notices the run that changed
something real.

**`changed_when: false`** for a command that only reads. **`creates:`** or
**`removes:`** for one that produces a file. Those two cover almost every case.

## Prove it twice, not once

```
cd /root/ansible
export LANG=C.UTF-8 LC_ALL=C.UTF-8
for run in 1 2; do
  echo "--- run $run ---"
  ansible-playbook site.yml | grep -E "^localhost" 
done
```{{exec}}

Two consecutive clean runs, because one quiet run immediately after a change
can happen by accident — a package that was already at the right version, a
service that happened to be up. Two cannot.

**And watch for `RUNNING HANDLER`.** A handler firing on a converged run means
something notified it that had not really changed, and that is a service
restart on every scheduled run — an outage you scheduled yourself.

**Done when:** two consecutive runs both report `changed=0`.
