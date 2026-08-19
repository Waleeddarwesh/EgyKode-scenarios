#!/bin/bash
# Criterion 4: secrets come from Vault, not from a variable in the repository.
#
# Two halves, and both are needed. The secret must have arrived on the host -
# otherwise "not in the repository" is satisfied by never fetching it at all -
# and it must appear nowhere under the playbook directory.
export LANG=C.UTF-8 LC_ALL=C.UTF-8
export VAULT_ADDR=${VAULT_ADDR:-http://127.0.0.1:8200}
export VAULT_TOKEN=${VAULT_TOKEN:-egykode-root}
A=/root/ansible
DEST=/etc/jenkins-admin-password

command -v vault >/dev/null 2>&1 || { echo "FAIL: vault is not installed"; exit 1; }
vault status >/dev/null 2>&1 || {
  echo "FAIL: the Vault dev server is not answering on $VAULT_ADDR"; exit 1; }

SECRET=$(vault kv get -field=admin_password secret/jenkins 2>/dev/null)
[ -n "$SECRET" ] || { echo "FAIL: no admin_password at secret/jenkins in Vault"; exit 1; }

# Presence: it actually reached the host.
[ -f "$DEST" ] || {
  echo "FAIL: $DEST does not exist"
  echo "      The playbook has not fetched the secret from Vault yet."
  exit 1; }

ON_HOST=$(cat "$DEST" 2>/dev/null)
if [ "$ON_HOST" != "$SECRET" ]; then
  echo "FAIL: the file on the host does not match what Vault holds"
  echo "      Something wrote a value that did not come from Vault - a"
  echo "      hardcoded default, or a stale copy from an earlier run."
  exit 1
fi

# And private. A secret readable by every user on the box has been moved, not
# protected.
MODE=$(stat -c '%a' "$DEST" 2>/dev/null)
[ "$MODE" = "600" ] || {
  echo "FAIL: $DEST is mode $MODE, expected 600"
  echo "      Fetching it safely and then leaving it world-readable undoes the"
  echo "      whole exercise."
  exit 1; }

# Absence: nowhere in the repository. This is the half the criterion names.
if grep -rq -- "$SECRET" "$A" 2>/dev/null; then
  echo "FAIL: the secret value appears inside $A"
  grep -rn -- "$SECRET" "$A" 2>/dev/null | head -3
  echo "      A value committed to the repository is a value everyone who ever"
  echo "      cloned it still has, including after you rotate it."
  exit 1
fi

# The token must not be baked in either - it is the one credential that cannot
# come from Vault, so it has to come from the environment.
if grep -rqE 'vault_token:\s*["'"'"']?egykode-root' "$A" 2>/dev/null; then
  echo "FAIL: the Vault token itself is hardcoded in the repository"
  echo "      Read it from the environment - lookup('env', 'VAULT_TOKEN') -"
  echo "      so the repository holds the address of the secret and never a"
  echo "      credential."
  exit 1
fi

grep -rq "hashi\|vault" "$A" 2>/dev/null || {
  echo "FAIL: nothing in the playbook references Vault at all"; exit 1; }

echo "PASS - the password reached the host from Vault, is mode 600, and appears nowhere in the repository"
exit 0
