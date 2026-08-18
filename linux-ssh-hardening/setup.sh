#!/bin/bash
# Install a package, refreshing the package lists only if the first attempt
# fails. An image with current lists stays fast; one with empty or stale lists
# still ends up with the package, instead of failing silently and leaving the
# learner to meet the gap two steps later.
install_pkg() {
  command -v "$2" >/dev/null 2>&1 && return 0
  DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "$1" >/dev/null 2>&1 && return 0
  apt-get update -qq >/dev/null 2>&1
  DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "$1" >/dev/null 2>&1
}

# sshd must be running for any of this to be observable.
install_pkg openssh-server sshd
systemctl enable --now ssh >/dev/null 2>&1 || systemctl enable --now sshd >/dev/null 2>&1

# ufw is configured but deliberately never enabled - see step 3.
install_pkg ufw ufw

echo done
