variable "os_version" {
  type = string
  description = "The version of the operating system to download and install"
}

variable "architecture" {
  default = "x86-64"
  type = string
  description = "The type of CPU to use when building"
}

variable "machine_type" {
  default = "q35"
  type = string
  description = "The type of machine to use when building"
}

variable "cpu_type" {
  default = "max"
  type = string
  description = "The type of CPU to use when building"
}

variable "memory" {
  default = 4096
  type = number
  description = "The amount of memory to use when building the VM in megabytes"
}

variable "cpus" {
  default = 4
  type = number
  description = "The number of cpus to use when building the VM"
}

variable "disk_size" {
  default = "12G"
  type = string
  description = "The size in bytes of the hard disk of the VM"
}

variable "checksum" {
  type = string
  description = "The checksum for the virtual hard drive file"
}

variable "root_password" {
  default = "vagrant"
  type = string
  description = "The password for the root user"
}

variable "secondary_user_password" {
  default = "vagrant"
  type = string
  description = "The password for the `secondary_user_username` user"
}

variable "secondary_user_username" {
  default = "vagrant"
  type = string
  description = "The name for the secondary user"
}

variable "headless" {
  default = false
  description = "When this value is set to `true`, the machine will start without a console"
}

variable "use_default_display" {
  default = true
  type = bool
  description = "If true, do not pass a -display option to qemu, allowing it to choose the default"
}

variable "display" {
  default = "cocoa"
  description = "What QEMU -display option to use"
}

variable "qmp_socket" {
  default = ""
  type = string
  description = "Path of a QMP socket to expose, for tools that drive the build interactively"
}

variable "acceleration" {
  default = true
  description = "Indicates if hardware acceleration should be enabled or not"
}

locals {
  iso_os_version = replace(var.os_version, ".", "")
  iso_target_extension = "iso"
  iso_target_path = "packer_cache"
  iso_full_target_path = "${local.iso_target_path}/${sha1(var.checksum)}.${local.iso_target_extension}"

  image = "OI-hipster-minimal-${local.iso_os_version}.${local.iso_target_extension}"
  vm_name = "openindiana-${var.os_version}-${var.architecture}.img"
}

source "qemu" "qemu" {
  machine_type = var.machine_type
  cpus = var.cpus
  memory = var.memory
  net_device = "virtio-net"

  disk_interface = "virtio"
  disk_size = var.disk_size

  # RAW, because that is what gets distributed (compressed with zstd, see
  # build.sh). Asking the builder for it directly avoids converting the image
  # afterwards.
  format = "raw"

  headless = var.headless
  use_default_display = var.use_default_display
  display = var.display
  accelerator = "none"

  boot_wait = "5s"

  boot_steps = [
    ["1<wait2m>", "Boot Multi User"],
    ["<enter><wait1m30s>", "Select keyboard layout"],
    ["<enter><wait2m30s>", "Select language"],

    // The post install script waits in the background for the installation
    // to finish, then configures the installed system and reboots into it.
    // Packer then waits for SSH instead of for a fixed install time.
    ["3<enter><wait5s>", "Installation menu - Shell"],
    ["curl -o /tmp/post_install.sh http://{{.HTTPIP}}:{{.HTTPPort}}/post_install.sh<enter><wait10>", "Download post install script"],
    ["nohup sh /tmp/post_install.sh > /tmp/post_install.log 2>&1 &<enter><wait>", "Start post install script"],
    ["exit<enter><wait5s>", "Back to installation menu"],

    ["1<enter><wait30s>", "Install OpenIndiana"],

    ["<f2><wait10s>", "Welcome to OpenIndiana - Continue"],
    ["<f2><wait>", "Where should OpenIndiana be installed - Continue"],
    ["<right>", "GPT disk warning - move to Continue"],
    ["<enter><wait5s>", "GPT disk warning - Continue"],
    ["<f2><wait>", "Use the whole disk (EFI) - Continue"],

    ["<down>", "Network - Automatically"],
    ["<f2><wait>", "Network - Continue"],
    ["<f2><wait>", "Time zone region - Continue"],
    ["<f2><wait>", "Date and time - Continue"],

    [var.root_password, "Root password"],
    ["<down>", "Move to confirm root password"],
    [var.root_password, "Confirm root password"],
    ["<down>", "Move to real name"],
    ["<down>", "Skip real name"],
    [var.secondary_user_username, "Username"],
    ["<down>", "Move to user password"],
    [var.secondary_user_password, "User password"],
    ["<down>", "Move to confirm user password"],
    [var.secondary_user_password, "Confirm user password"],
    ["<f2><wait>", "Users - Continue"],

    ["<f2>", "Install summary - Install"],
  ]

  ssh_username = "root"
  ssh_password = var.root_password
  ssh_timeout = "10000s"

  qemuargs = concat(
    var.acceleration ? [["-accel", "kvm"], ["-accel", "hvf"], ["-accel", "tcg"]] : [],
    var.qmp_socket == "" ? [] : [["-qmp", "unix:${var.qmp_socket},server=on,wait=off"]],
    [
      ["-cpu", var.cpu_type],

      // Boot the disk first, which falls through to the CD while the disk is
      // still empty. The firmware is QEMU's default, SeaBIOS, the same as the
      // action boots the image with.
      //
      // The disk is at the same PCI address as where the action attaches it.
      // ZFS records the device path of the pool, and when it changes, the boot
      // scans every device for the pool, which can make the boot-archive
      // service time out without hardware acceleration.
      ["-device", "virtio-blk-pci,drive=drive0,bootindex=0,addr=0x02"],
      ["-device", "ide-cd,drive=cdrom0,bootindex=1"],
      ["-drive", "if=none,id=drive0,file={{ .OutputDir }}/{{ .Name }},cache=writeback,discard=ignore,format=raw"],
      ["-drive", "if=none,id=cdrom0,file=${local.iso_full_target_path},media=cdrom,readonly=on"]
    ]
  )

  iso_checksum = var.checksum
  iso_target_extension = local.iso_target_extension
  iso_target_path = local.iso_target_path
  iso_urls = [
    "https://mirrors.dotsrc.org/openindiana/isos/hipster/${local.iso_os_version}/${local.image}",
    "https://dlc.openindiana.org/isos/hipster/${local.iso_os_version}/${local.image}"
  ]

  http_directory = "resources"
  output_directory = "output"
  shutdown_command = "shutdown -i5 -g0 -y"
  vm_name = local.vm_name
}

packer {
  required_plugins {
    qemu = {
      version = "~> 1.1"
      source = "github.com/hashicorp/qemu"
    }
  }
}

build {
  sources = ["qemu.qemu"]

  provisioner "shell" {
    script = "resources/provision.sh"
    environment_vars = [
      "SECONDARY_USER=${var.secondary_user_username}"
    ]
  }

  provisioner "shell" {
    script = "resources/custom.sh"
  }

  provisioner "shell" {
    script = "resources/cleanup.sh"
  }
}
