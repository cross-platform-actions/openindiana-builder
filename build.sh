#!/usr/bin/env sh

set -eux

OS_VERSION="$1"; shift
ARCHITECTURE="$1"; shift

# Turn the image's remaining zero ranges into holes. tar uses SEEK_HOLE rather
# than looking for zeroes itself, so only holes stay out of the archive.
# resources/cleanup.sh already trims the unused space of the pool into holes;
# this catches the zeroes the installation itself wrote.
#
# `fallocate` is Linux-only and works in place. Elsewhere a raw-to-raw qemu-img
# conversion skips the zero blocks and so writes a sparse file.
sparsify() {
  image="$1"

  if command -v fallocate > /dev/null 2>&1; then
    fallocate --dig-holes "$image"
  else
    qemu-img convert -f raw -O raw "$image" "$image.sparse"
    mv "$image.sparse" "$image"
  fi

  echo "image: $(du -h "$image" | cut -f1) on disk, \
$(ls -l "$image" | awk '{print $5}') bytes virtual"
}

# One artifact per image, holding a RAW `disk.img`, the same bundle as the
# NetBSD builder produces, so the action needs one code path for both. -19
# --long=27 is the knee of the size/speed curve, and a 128 MiB window is zstd's
# default decompression limit, so the consumer needs no --long to unpack.
bundle_image() {
  raw="output/openindiana-$OS_VERSION-$ARCHITECTURE.img"
  bundle="output/openindiana-$OS_VERSION-$ARCHITECTURE.tar.zst"

  # Staged inside output/ so that renaming a 256 GB file stays a rename rather
  # than becoming a copy onto another file system.
  rm -rf output/bundle
  mkdir -p output/bundle
  mv "$raw" output/bundle/disk.img

  sparsify output/bundle/disk.img

  # GNU tar, as BSD tar has no --sparse. Through a file rather than a pipe, so
  # a failing tar stops the script before the image is deleted below.
  tar_command=$(command -v gtar || echo tar)

  "$tar_command" --sparse -C output/bundle -cf output/bundle.tar disk.img
  zstd -19 --long=27 -T0 --rm -o "$bundle" -f output/bundle.tar

  rm -rf output/bundle
  ls -l "$bundle"
}

packer init .

packer build \
  -var os_version="$OS_VERSION" \
  -var-file "var_files/common.pkrvars.hcl" \
  -var-file "var_files/$ARCHITECTURE.pkrvars.hcl" \
  -var-file "var_files/$OS_VERSION/$ARCHITECTURE.pkrvars.hcl" \
  "$@" \
  main.pkr.hcl

bundle_image
