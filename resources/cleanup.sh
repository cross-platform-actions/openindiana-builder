#!/bin/sh

set -exu

cleanup() {
  pkg purge-history
  rm -rf /var/pkg/publisher/*/file
}

# The installer snapshots the boot environment, and the snapshot of /var keeps
# everything provisioning has since replaced or removed, about 1 GB.
destroy_install_snapshots() {
  zfs destroy -r rpool/ROOT/openindiana@install
}

# The dedicated dump device is fully allocated, 2 GB, and a crash dump is of
# no use in a VM that only lives for one job.
remove_dump_device() {
  dumpadm -d none
  zfs destroy rpool/dump
}

# Fills the unused space of the pool with zeros, which build.sh turns into
# holes before archiving the image.
minimize_disk() {
  mdb -kwe 'zfs_initialize_value/z0'
  zpool initialize rpool
  wait_for_initialize
}

wait_for_initialize() {
  while zpool status rpool | grep -q '(initializing)'; do
    sleep 10
  done
  zpool status rpool
}

cleanup
destroy_install_snapshots
remove_dump_device
minimize_disk
