#!/bin/bash
# Runs as intro.background. Installs Ansible and a Vault dev server, and
# deliberately installs NOTHING the playbook is supposed to install - the
# whole point of step 1 is watching a bare host become a build host, and a
# package that is already present hides the difference between the first run
# and the second.

set -u

# Ansible refuses to start without a UTF-8 locale, with "Ansible requires the
# locale encoding to be UTF-8; Detected None". Minimal images often have none
# set, and the error names the locale rather than anything the learner did.
export LANG=C.UTF-8 LC_ALL=C.UTF-8
grep -q 'LANG=C.UTF-8' /root/.bashrc 2>/dev/null || \
  printf 'export LANG=C.UTF-8\nexport LC_ALL=C.UTF-8\n' >> /root/.bashrc

echo "Installing Ansible..."
if ! command -v ansible-playbook >/dev/null 2>&1; then
  apt-get update -qq >/dev/null 2>&1
  DEBIAN_FRONTEND=noninteractive apt-get install -y -qq ansible curl jq unzip >/dev/null 2>&1
fi
ansible --version 2>/dev/null | head -1

echo "Installing Vault (dev mode)..."
# The binary rather than a container: this scenario needs no Docker otherwise,
# and one fewer moving part is one fewer thing to debug when a step fails.
if ! command -v vault >/dev/null 2>&1; then
  curl -fsSL https://releases.hashicorp.com/vault/1.15.6/vault_1.15.6_linux_amd64.zip -o /tmp/vault.zip 2>/dev/null
  unzip -q -o /tmp/vault.zip -d /usr/local/bin 2>/dev/null
fi

pkill -f 'vault server -dev' >/dev/null 2>&1
nohup vault server -dev -dev-root-token-id=egykode-root \
  -dev-listen-address=0.0.0.0:8200 >/var/log/vault.log 2>&1 &

export VAULT_ADDR=http://127.0.0.1:8200
export VAULT_TOKEN=egykode-root
grep -q 'VAULT_ADDR' /root/.bashrc 2>/dev/null || \
  printf 'export VAULT_ADDR=http://127.0.0.1:8200\nexport VAULT_TOKEN=egykode-root\n' >> /root/.bashrc

for i in $(seq 1 30); do
  vault status >/dev/null 2>&1 && break
  sleep 2
done

# The secret the playbook will fetch. It exists only in Vault; nothing in
# /root/ansible will ever contain this string, which is what criterion 4 is.
vault kv put secret/jenkins admin_password='NotInTheRepo-8f3c1d' >/dev/null 2>&1
echo "  vault: $(vault kv get -field=admin_password secret/jenkins 2>/dev/null | head -c 6)... stored"

mkdir -p /root/ansible/roles/common/tasks \
         /root/ansible/roles/java/tasks \
         /root/ansible/roles/jenkins/tasks \
         /root/ansible/roles/jenkins/handlers

cat > /root/ansible/ansible.cfg <<'CFG'
[defaults]
inventory = inventory.ini
stdout_callback = default
retry_files_enabled = False
CFG

cat > /root/ansible/inventory.ini <<'INI'
[build]
localhost ansible_connection=local
INI

echo done
