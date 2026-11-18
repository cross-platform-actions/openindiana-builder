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
* [QEMU](https://qemu.org)

####  [UEFI firmware](https://github.com/tianocore/edk2)

The VM boots using UEFI. The firmware needs to be located at
`resources/ovmf.fd`. Copy the `OVMF.fd` file from its install location to
`resources/ovmf.fd`.

* **Ubuntu** - Install the [`ovmf`](https://packages.ubuntu.com/noble/ovmf)
    package and copy `/usr/share/ovmf/OVMF.fd`
* **Fedora** - Install the `edk2-ovmf` package
* **macOS** - Copy the `OVMF.fd` file from a Linux machine

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

The above command will build the VM image and the resulting disk image will be
at the path: `output/openindiana-2026.10.30-x86-64.qcow2`.

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

The qcow2 format is chosen because unused space doesn't take up any space on
disk, it's compressible and easily converts the raw format.
