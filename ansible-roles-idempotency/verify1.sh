#!/bin/bash
R=/root/ansible/roles/webserver
[ -d "$R" ] || { echo "FAIL: no $R"; exit 1; }

for D in tasks defaults templates handlers; do
  [ -d "$R/$D" ] || { echo "FAIL: no $R/$D directory"; exit 1; }
done
[ -f "$R/tasks/main.yml" ] || { echo "FAIL: no tasks/main.yml"; exit 1; }
[ -f "$R/defaults/main.yml" ] || { echo "FAIL: no defaults/main.yml"; exit 1; }

# The criterion: values come from variables. A task naming the package directly
# works perfectly and cannot be reused, which is the whole point of the step.
grep -qE 'name: *"?\{\{ *webserver_package' "$R/tasks/main.yml" || {
  echo "FAIL: the install task does not take its package name from a variable"; exit 1; }
grep -q "webserver_package" "$R/defaults/main.yml" || {
  echo "FAIL: webserver_package is not defined in defaults/"; exit 1; }

# In defaults, not vars - anything in vars/ cannot be overridden by a caller.
if [ -f "$R/vars/main.yml" ]; then
  grep -qE "^webserver_(package|port|server_name|worker_connections):" "$R/vars/main.yml" && {
    echo "FAIL: overridable values are in vars/, where a caller cannot override them"
    echo "      Move them to defaults/main.yml."
    exit 1; }
fi

# validate: is what stops a broken template reaching the running service.
grep -q "validate:" "$R/tasks/main.yml" || {
  echo "FAIL: the template task has no validate: - a broken config would be installed"; exit 1; }

# The template must actually use the variables rather than repeat their values.
T="$R/templates/nginx.conf.j2"
[ -f "$T" ] || { echo "FAIL: no templates/nginx.conf.j2"; exit 1; }
grep -q "{{ webserver_worker_connections }}" "$T" || {
  echo "FAIL: the template hardcodes worker_connections instead of using the variable"; exit 1; }

# And the whole thing has to parse as Ansible YAML.
cd /root/ansible && ansible-playbook --syntax-check -i localhost, /dev/null >/dev/null 2>&1
python3 -c "import yaml,sys; yaml.safe_load(open('$R/tasks/main.yml')); yaml.safe_load(open('$R/defaults/main.yml'))" 2>/dev/null || {
  echo "FAIL: tasks/main.yml or defaults/main.yml is not valid YAML"; exit 1; }

echo "PASS - the role is laid out correctly and takes its values from defaults"
exit 0
