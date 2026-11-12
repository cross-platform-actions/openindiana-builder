#!/bin/sh

# Runs in the live environment of the installer, after the installation has
# completed. It configures the installed boot environment, mounted at
# $TARGET, so that Packer can connect as root over SSH after the reboot.

set -eux

TARGET=/a
BOOT_ENVIRONMENT=openindiana

mount_boot_environment() {
  if [ ! -d "$TARGET/etc" ]; then
    mkdir -p "$TARGET"
    beadm mount "$BOOT_ENVIRONMENT" "$TARGET"
  fi
}

# The installer makes root a role, and roles cannot log in over SSH.
make_root_a_normal_user() {
  sed -e '/^root:/s/;type=role//' -e '/^root:/s/type=role;//' \
    "$TARGET/etc/user_attr" > /tmp/user_attr
  cat /tmp/user_attr > "$TARGET/etc/user_attr"
}

configure_ssh() {
  # sshd uses the first occurrence of an option, so drop the stock ones.
  sed '/^PermitRootLogin/d; /^PasswordAuthentication/d; /^PermitEmptyPasswords/d' \
    "$TARGET/etc/ssh/sshd_config" > /tmp/sshd_config

  cat /tmp/sshd_config - > "$TARGET/etc/ssh/sshd_config" <<EOF
PermitRootLogin yes
PasswordAuthentication yes
PubkeyAuthentication yes
UseDNS no
AcceptEnv *
PermitEmptyPasswords yes
EOF
}

unmount_boot_environment() {
  sync
  beadm unmount "$BOOT_ENVIRONMENT" || :
}

mount_boot_environment
make_root_a_normal_user
configure_ssh
grep '^root:' "$TARGET/etc/user_attr"
unmount_boot_environment
