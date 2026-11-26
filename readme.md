# OpenIndiana Builder

This project builds the OpenIndiana VM image for the
[cross-platform-actions/action](https://github.com/cross-platform-actions/action)
GitHub action. The image contains a minimal OpenIndiana Hipster installation,
installed from the text installer, without any graphical environment.

The following packages are installed as well:

* bash
* curl
* GNU coreutils (for `whoami`)
* rsync
* sudo

Except for the root user, there's one additional user, `runner`, which is the
user that will be running the commands in the GitHub action. This user is
allowed use `sudo` without a password.

## Architectures and Versions

The following architectures and versions are supported:

| Version    | x86-64 |
|------------|--------|
| 2026.10.30 | ✓      |

## Building Locally

### Prerequisite

* [Packer](https://www.packer.io) 1.14.2 or later
* [QEMU](https://qemu.org), including `qemu-img`
* [zstd](https://github.com/facebook/zstd), to compress the resulting image
* GNU tar, for its `--sparse` option. On macOS it's available as `gtar` from
    Homebrew (`brew install gnu-tar`)

### Building

1. Clone the repository:
    ```
    git clone https://github.com/cross-platform-actions/openindiana-builder
    cd openindiana-builder
    ```

2. Run `build.sh` to build the image:
    ```
    ./build.sh <version> <architecture>
    ```
    Where `<version>` and `<architecture>` are the any of the versions or
    architectures available in the above table.

The above command will build the VM image and the resulting image will be at
the path: `output/openindiana-2026.10.30-x86-64.tar.zst`.

### Customizing the Image

Additional provisioning can be added to `resources/custom.sh`. It runs after
the standard provisioning and before the disk image is cleaned up and
minimized.

## Additional Information

The installer is driven by typing into the VM console with fixed delays
between the steps. On a slow host, for example when running without hardware
acceleration, the delays might need to be increased. The installation itself
is not a fixed delay: `resources/post_install.sh` waits in the background
until the installer marks the root pool as ready, then configures the
installed system and reboots into it.

The image is distributed as a single artifact,
`openindiana-<version>-<architecture>.tar.zst`, holding `disk.img`, the RAW
disk. This is the same format as the
[NetBSD builder](https://github.com/cross-platform-actions/netbsd-builder)
uses, so the action unpacks both the same way. qcow2 is not used: its own
compression has to keep the image writable, so it compresses worse than a
solid stream does, and a consumer pays that difference on every job. The
measured numbers are in
[action#151](https://github.com/cross-platform-actions/action/issues/151).

The unused space of the pool is zero-filled before the image is archived, and
the zero ranges are turned into actual holes, which the tar records rather than
the zeroes in them. Neither end has to read or write the full 24 GB, only the
space the installation uses. The compression window is kept at zstd's default
decompression limit, so no extra flags are needed to unpack it:

```
curl -sL <url>/openindiana-<version>-<architecture>.tar.zst | zstd -dc | tar -x
```

## Contributing

### Changelog

The changelog is maintained in the [changelog.md](changelog.md) file, following
the [Keep a Changelog] format. The changelog is updated incrementally. That is,
for every new feature or bugfix, add an entry to the changelog under the
[Unreleased] section using an appropriate sub header (`Added`, `Changed`,
`Deprecated`, `Removed`, `Fixed`, or `Security`).

Entries under these sub headers determine the semantic version bump when the
next release is cut with [relog].

### Creating a Release

Releases are cut with [relog], driven by the [Unreleased] section of
`changelog.md`. relog derives the next version from the sub headers under
[Unreleased]:

* `### Fixed` only → patch bump
* `### Added`, `### Changed`, `### Deprecated` → minor bump
* `### Removed` (or "Breaking" anywhere in the section) → major bump

To cut a release, from a clean `master` working tree, run:

```
relog
```

To preview the changes without modifying anything:

```
relog --dry-run
```

To override the auto-detected version:

```
relog X.Y.Z
```

relog rewrites the changelog, commits the result, creates an annotated `vX.Y.Z`
tag, and prompts before pushing. Pushing the `vX.Y.Z` tag triggers the GitHub
Actions workflow defined in
[`.github/workflows/build.yml`](.github/workflows/build.yml), which builds the
VM images and, in the "Create Release" step, creates a draft GitHub release
using the newly added changelog section as the release notes. Review the draft
release on GitHub and publish it.

[Keep a Changelog]: https://keepachangelog.com/en/1.1.0/
[relog]: https://github.com/jacob-carlborg/relog
[Unreleased]: https://github.com/cross-platform-actions/openindiana-builder/blob/master/changelog.md#unreleased
