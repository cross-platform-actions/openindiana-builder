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
  wait_for_trim
}

# illumos' `zpool wait` can't wait for a trim. Fails unless the trim completed,
# for example when the disk doesn't support it.
wait_for_trim() {
  while zpool status -t rpool | grep -q 'trimmed, started at'; do
    sleep 5
  done
  zpool status -t rpool
  zpool status -t rpool | grep -q '100% trimmed, completed at'
}

cleanup
destroy_install_snapshots
remove_dump_device
minimize_disk
