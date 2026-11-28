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

# Trims the unused space of the pool, which QEMU turns into holes in the image,
# so neither the build nor the action stores more than the installation uses.
# Writing zeros instead would fully allocate the image on the build host, which
# has less free space than the disk is large.
minimize_disk() {
  zpool trim rpool
  zpool wait -t trim rpool
  zpool status -t rpool
}

cleanup
destroy_install_snapshots
remove_dump_device
minimize_disk
