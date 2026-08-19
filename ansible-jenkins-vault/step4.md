# A verify playbook that fails loudly

A provisioning run that ends `failed=0` proves the tasks ran. It does not prove
the host works — a service can be `enabled`, start, and die three seconds later
with the playbook long finished and green.

So write the play that asks the host whether it is actually working:

```
cd /root/ansible
cat > verify.yml <<'YAML'
- name: Assert the build host is actually a build host
  hosts: build
  become: false
  tasks:
    - name: Required binaries are on PATH
      # shell, not command: `command -v` is a shell builtin, and the command
      # module executes directly with no shell, so it fails with
      # "No such file or directory: b'command'" even when the binary is there.
      ansible.builtin.shell: "command -v {{ item }}"
      loop:
        - java
        - git
        - curl
      changed_when: false
      register: binaries
      failed_when: binaries.rc != 0

    - name: Java is new enough for Jenkins
      ansible.builtin.shell: "java -version 2>&1 | head -1"
      changed_when: false
      register: javaver
      failed_when: >-
        ('"21' not in javaver.stdout) and ('"25' not in javaver.stdout)

    - name: Jenkins is running, not merely enabled
      ansible.builtin.systemd_service:
        name: jenkins
      register: jenkins_unit
      failed_when: jenkins_unit.status.ActiveState != "active"

    - name: Jenkins answers on its port
      ansible.builtin.uri:
        url: http://localhost:8080/login
        status_code: [200, 403]
        timeout: 10

    - name: The admin password came from Vault and is not world readable
      ansible.builtin.stat:
        path: /etc/jenkins-admin-password
      register: pw
      failed_when: (not pw.stat.exists) or (pw.stat.mode != '0600')

    - name: Say so
      ansible.builtin.debug:
        msg: "build host verified: java, git, curl, jenkins active and answering, secret 0600"
YAML
echo "verify.yml written"
```{{exec}}

## Run it against a working host

```
cd /root/ansible
export LANG=C.UTF-8 LC_ALL=C.UTF-8 VAULT_TOKEN=egykode-root
ansible-playbook verify.yml | tail -10
```{{exec}}

## Now break something and watch it refuse

This is the half people skip. A check you have never seen fail is not a check:

```
cd /root/ansible
export LANG=C.UTF-8 LC_ALL=C.UTF-8
mv /usr/bin/git /usr/bin/git.hidden
ansible-playbook verify.yml 2>&1 | tail -12
echo "playbook exit code: ${PIPESTATUS[0]}"
```{{exec}}

A named task, a non-zero exit, and the loop item that failed printed in the
output. **`failed_when` is what turns a command into an assertion** — without
it, `command -v git` returning 1 is just a task result nobody reads.

Put it back:

```
mv /usr/bin/git.hidden /usr/bin/git
cd /root/ansible
export LANG=C.UTF-8 LC_ALL=C.UTF-8 VAULT_TOKEN=egykode-root
ansible-playbook verify.yml | grep -E "^localhost|build host verified"
```{{exec}}

## Why the service check is written that way

```
cd /root/ansible
grep -A3 "Jenkins is running, not merely enabled" verify.yml
```{{exec}}

`ActiveState != "active"` rather than trusting the module's own result.
`systemd_service` with no `state:` only *queries*, so it always reports success
— the assertion has to be about what it found. The distinction between
`enabled` and `active` is exactly the one that lets a host pass provisioning
and fail at 3am after a reboot.

**In production this play runs on a schedule**, not once after provisioning.
Drift is the normal case: someone stops a service to debug it, a disk fills, a
package is downgraded by an unrelated update. A verify play that runs nightly
turns all of those into an email instead of an incident.

**Done when:** `verify.yml` passes on the working host and exits non-zero when
a required binary is missing.
