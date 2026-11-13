#!/bin/sh

# Runs in the background in the live environment of the installer. It's
# started before the installation, waits for the installer to finish, then
# configures the installed boot environment, mounted at $TARGET, so that
# Packer can connect as root over SSH, and reboots into it.

set -eux

TARGET=/a
BOOT_ENVIRONMENT=openindiana
POOL=rpool

# The last step of the installer marks the pool as ready. The pool doesn't
# exist until the installer creates it.
wait_for_installation() {
  until [ "$(zfs get -H -o value org.openindiana.caiman:install "$POOL" 2>/dev/null)" = ready ]; do
    sleep 10
  done
}

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

wait_for_installation
mount_boot_environment
make_root_a_normal_user
configure_ssh
grep '^root:' "$TARGET/etc/user_attr"
unmount_boot_environment
reboot
