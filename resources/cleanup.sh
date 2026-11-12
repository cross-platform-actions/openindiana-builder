#!/bin/sh

set -exu

cleanup() {
  pkg purge-history
  rm -rf /var/pkg/publisher/*/file
}

# Fills the unused space of the pool with zeros, which compress away when
# Packer converts the disk image.
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
minimize_disk
