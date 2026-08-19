# The password that is not in the repository

There is a secret in Vault, put there by setup:

```
export VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=egykode-root
vault kv get secret/jenkins
```{{exec}}

The job is to get that value onto the host **without it ever existing in the
playbook, in a vars file, or in your shell history**.

## Read it from Vault at run time

```
cd /root/ansible
cat >> roles/jenkins/tasks/main.yml <<'YAML'

- name: Read the Jenkins admin password from Vault
  ansible.builtin.uri:
    url: "{{ vault_addr }}/v1/secret/data/jenkins"
    headers:
      X-Vault-Token: "{{ vault_token }}"
    return_content: true
  register: vault_jenkins
  changed_when: false
  no_log: true

- name: Install it where only root can read it
  ansible.builtin.copy:
    content: "{{ vault_jenkins.json.data.data.admin_password }}"
    dest: /etc/jenkins-admin-password
    owner: root
    group: root
    mode: "0600"
  no_log: true
YAML

cat > group_vars_build.yml <<'YAML'
# Not a secret between them: an address, and a token read from the environment.
vault_addr: "http://127.0.0.1:8200"
vault_token: "{{ lookup('env', 'VAULT_TOKEN') }}"
YAML
mkdir -p group_vars && mv group_vars_build.yml group_vars/build.yml
echo "vault tasks appended"
```{{exec}}

Three things there are the whole lesson:

**`lookup('env', 'VAULT_TOKEN')`.** The token is the one credential that cannot
come from Vault, so it comes from the environment — injected by whatever runs
the playbook. In production that is a CI secret store or an AppRole login, and
the principle is the same: the repository holds the *address* of the secret,
never the secret.

**`changed_when: false`** on the `uri` task. Reading is not changing, and
without it every run reports a change forever — the thing step 2 warned about.

**`no_log: true`** on both. Without it Ansible prints the registered value on
`-v`, and the fetched password lands in the job log of whatever ran it. This is
the most common way a secret escapes a correct Vault setup.

## Run it and check both ends

```
cd /root/ansible
export LANG=C.UTF-8 LC_ALL=C.UTF-8 VAULT_TOKEN=egykode-root
ansible-playbook site.yml | tail -8
echo "--- what landed on the host ---"
ls -l /etc/jenkins-admin-password
cat /etc/jenkins-admin-password; echo
```{{exec}}

## Now the part that matters

```
cd /root/ansible
echo "searching the whole repository for the secret value:"
grep -rn 'NotInTheRepo-8f3c1d' . 2>/dev/null && echo "FOUND - that is a leak" || echo "not present anywhere in the repository"
echo ""
echo "what the repository does contain:"
grep -rn 'vault_' group_vars/build.yml
```{{exec}}

An address and an environment lookup. The secret exists in exactly two places —
Vault, and a `0600` file on the host that needed it.

**Why this beats `ansible-vault`.** An `ansible-vault` encrypted file is still
*in the repository*: rotating a password means a commit, and everyone who ever
cloned it has the old ciphertext and possibly the vault password. A secret
fetched at run time is rotated in one place, and revoking access is revoking a
token rather than rewriting history.

**Done when:** the password is on the host from Vault, and grepping the whole
repository for it finds nothing.
