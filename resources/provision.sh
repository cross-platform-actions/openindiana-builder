#!/bin/sh

set -exu

# By default pkg keeps the downloaded packages after installing them: 1.8 GB
# after installing a typical set of build dependencies.
flush_package_cache_after_install() {
  pkg set-property flush-content-cache-on-success True
}

# pkg exits with 4 when there is nothing to do. gnu-coreutils provides
# whoami, which the minimal installation doesn't include. gcc-14 is the
# version OpenIndiana builds its own packages with, and brings the system
# headers, linker and binutils.
install_extra_packages() {
  pkg install --accept bash curl developer/gcc-14 file/gnu-coreutils rsync \
    sudo || [ $? -eq 4 ]
}

# Other platforms provide the system C compiler as `cc`, which build systems
# fall back to. No OpenIndiana package delivers it. A link rather than a
# script, so it follows the gcc mediator if the default version changes.
link_cc_to_gcc() {
  ln -s gcc /usr/bin/cc
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

# autofs mounts /home read-only, which prevents the action from creating the
# work directory, `/home/runner/work/<repo>/<repo>`.
disable_autofs() {
  svcadm disable -s system/filesystem/autofs
}

flush_package_cache_after_install
install_extra_packages
link_cc_to_gcc
setup_sudo
configure_boot_flags
remove_secondary_user_password
set_hostname
disable_autofs
