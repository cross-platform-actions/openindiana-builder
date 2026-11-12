#!/bin/sh

set -exu

# pkg exits with 4 when there is nothing to do.
install_extra_packages() {
  pkg install --accept bash curl rsync sudo || [ $? -eq 4 ]
}

setup_sudo() {
  cat <<EOF > "/etc/sudoers.d/$SECONDARY_USER"
Defaults:$SECONDARY_USER !requiretty
$SECONDARY_USER ALL=(ALL) NOPASSWD: ALL
EOF

  chmod 440 "/etc/sudoers.d/$SECONDARY_USER"
}

configure_boot_flags() {
  echo 'autoboot_delay="-1"' >> /boot/loader.conf.local
  echo 'beastie_disable="YES"' >> /boot/loader.conf.local
}

remove_secondary_user_password() {
  passwd -d "$SECONDARY_USER"
}

set_hostname() {
  echo 'runnervmg1sw1.local' > /etc/nodename
}

install_extra_packages
setup_sudo
configure_boot_flags
remove_secondary_user_password
set_hostname
