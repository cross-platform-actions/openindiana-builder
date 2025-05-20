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
  default = "pc"
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
  vm_name = "openindiana-${var.os_version}-${var.architecture}.qcow2"
}

source "qemu" "qemu" {
  machine_type = var.machine_type
  cpus = var.cpus
  memory = var.memory
  net_device = "virtio-net"

  disk_compression = true
  disk_interface = "virtio"
  disk_size = var.disk_size
  format = "qcow2"

  headless = var.headless
  use_default_display = var.use_default_display
  display = var.display
  accelerator = "none"
  firmware = "uefi.fd"

  boot_wait = "5s"

  boot_steps = [
    ["1<wait1m>", "Boot Multi User"],
    ["<enter><wait5s>", "To select the keyboard layout, enter a number [default 47]:"],
    ["<enter><wait2m>", "To select the language you wish to use, enter a number [default is 1]:"],
    ["1<enter><wait30s>", "Install OpenIndiana"],

    // Welcome to OpenIndiana
    ["<f2><wait10s>", "Continue"],

    // Where should OpenIndiana be installed?
    ["<f2><wait>", "Continue"],

    // You have chosen a GPT labeled disk. Installing onto a GPT labeled disk
    // will cause the loss of all existing data
    ["<right>", "move to Continue"],
    ["<enter><wait5s>", "Continue"],

    // Fdisk Partitions
    ["<f2><wait>", "Use the whole disk (EFI) - Continue"],

    // Network - Select how the wired ethernet network connection is configured
    ["<down>", "Automatically"],
    ["<f2><wait>", "Continue"],

    // Select the region that contains your time zone
    ["<f2><wait>", "Continue"],

    // Date and Time
    ["<f2><wait>", "Continue"],

    // Users
    // System Root Password
    [var.root_password, "Root password"],
    ["<down>"],
    [var.root_password, "Confirm password"],
    ["<down>"],

    // Create a user account
    ["<down>", "Your real name"],
    [var.secondary_user_username, "Username"],
    ["<down>"],
    [var.secondary_user_password, "User password"],
    ["<down>"],
    [var.secondary_user_password, "Confirm password"],
    ["<f2><wait>", "Continue"],

    // Install Summary
    ["<f2><wait30m>", "Install"], # try 25m

    // Installation Compelte
    ["<f9><wait5s>", "Quit"],

    // Welcome to OpenIndiana installation menu
    ["3<enter><wait5s>", "Shell"],

    // shell
    ["curl -o /tmp/post_install.sh http://{{.HTTPIP}}:{{.HTTPPort}}/resources/post_install.sh<enter><wait10>"],
    ["sh /tmp/post_install.sh && exit<enter><wait5>"],

    // Welcome to OpenIndiana installation menu
    ["5<enter>", "Reboot"],
  ]

  ssh_username = "root"
  ssh_password = var.root_password
  ssh_timeout = "10000s"

  qemuargs = concat(
    var.acceleration ? [["-accel", "kvm"], ["-accel", "hvf"], ["-accel", "tcg"]] : [],

    [
      ["-cpu", var.cpu_type],
      ["-boot", "strict=off"],
      ["-monitor", "none"],
      ["-device", "virtio-scsi-pci"],
      ["-device", "virtio-blk,drive=drive0,bootindex=0"],
      ["-device", "ide-cd,drive=drive1,bootindex=1"],
      ["-drive", "if=none,file={{ .OutputDir }}/{{ .Name }},id=drive0,cache=writeback,discard=ignore,format=qcow2"],
      ["-drive", "if=none,file=${local.iso_full_target_path},id=drive1,media=disk,format=raw,readonly=on"]
    ]
  )

  iso_checksum = var.checksum
  iso_target_extension = local.iso_target_extension
  iso_target_path = local.iso_target_path
  iso_urls = [
    "https://mirrors.dotsrc.org/openindiana/isos/hipster/${local.iso_os_version}/${local.image}",
    "https://dlc.openindiana.org/isos/hipster/${local.iso_os_version}/${local.image}"
  ]

  http_directory = "."
  output_directory = "output"
  shutdown_command = "/sbin/poweroff"
  vm_name = local.vm_name
}

packer {
  required_plugins {
    qemu = {
      version = "~> 1.0.8"
      source = "github.com/hashicorp/qemu"
    }
  }
}

build {
  sources = ["qemu.qemu"]

  /*provisioner "shell" {
    script = "resources/provision.sh"
    environment_vars = [
      "SECONDARY_USER=${var.secondary_user_username}"
    ]
  }*/
}
