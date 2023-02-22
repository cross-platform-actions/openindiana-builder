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
  default = 2
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

variable "accelerator" {
  default = "tcg"
  type = string
  description = "The accelerator type to use when running the VM"
}

locals {
  iso_os_version = replace(var.os_version, ".", "")
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
  accelerator = var.accelerator

  boot_wait = "5s"

  boot_steps = [
    ["1<wait5m>", "Boot Multi User"],
    ["<enter><wait10s>", "To select the keyboard layout, enter a number [default 47]:"],
    ["<enter><wait10s>", "To select the language you wish to use, enter a number [default is 1]:"],
    ["1<enter><wait20s>", "Install OpenIndiana"],

    // Welcome to OpenIndiana
    ["<f2><wait>", "Continue"],

    // Where should OpenIndiana be installed?
    ["<f2><wait>", "Continue"],

    // You have chosen a GPT labeled disk. Installing onto a GPT labeled disk
    // will cause the loss of all existing data
    ["<left>", "move to Continue"],
    ["<enter><wait>", "Continue"],

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
    ["<f2><wait25m>", "Install"],
  ]

  ssh_username = "root"
  ssh_password = var.root_password
  ssh_timeout = "10000s"

  qemuargs = [
    ["-cpu", var.cpu_type],
    ["-monitor", "none"]
  ]

  iso_checksum = var.checksum
  iso_urls = [
    "https://dlc.openindiana.org/isos/hipster/${local.iso_os_version}/OI-hipster-minimal-${local.iso_os_version}.iso"
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

  provisioner "shell" {
    script = "resources/provision.sh"
    environment_vars = [
      "SECONDARY_USER=${var.secondary_user_username}"
    ]
  }
}
