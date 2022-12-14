# variables that can be overriden
variable "hostname" { default = "ztp-sno" }
variable "memory" { default = 32 }
variable "cpu" { default = 8 }
variable "vm_mac_address" { default = "52:54:00:bd:ab:cc" }
variable "vm_volume_size" { default = 105 }
variable "vm_net_ip" { default = "192.168.210.7" }
variable "local_volume_size" { default = 50 }
variable "local_volume_enabled" { default = false }
variable "libvirt_network" { default = "ztp" }
variable "libvirt_pool" { default = "ztp" }

provider "libvirt" {
  uri = "qemu:///system"
}

resource "libvirt_volume" "os_image" {
  name = "${var.hostname}-os_image"
  size = var.vm_volume_size*1073741824
  pool = var.libvirt_pool
  format = "qcow2"
}

resource "libvirt_volume" "local_disk" {
  count = tobool(lower(var.local_volume_enabled)) ? 1 : 0
  name = "${var.hostname}-local_disk"
  pool = var.libvirt_pool
  size = var.local_volume_size*1073741824
  format = "qcow2"
}

# Create the machine
resource "libvirt_domain" "master" {
  count = 1
  name = var.hostname
  memory = var.memory*1024
  machine = "q35"
  firmware = "/usr/share/edk2/ovmf/OVMF_CODE.secboot.fd"
  vcpu = var.cpu

  cpu {
    mode = "host-passthrough"
  }

  disk {
    volume_id = libvirt_volume.os_image.id
  }

  dynamic "disk" {
    for_each = tobool(lower(var.local_volume_enabled)) ? { storage = true } : {}
    content {
    volume_id = libvirt_volume.local_disk[count.index].id
    }
   }

  network_interface {
    hostname = var.hostname
    network_name = var.libvirt_network
    mac = var.vm_mac_address
    addresses = [ var.vm_net_ip ]
  }

  boot_device {
    dev = [ "hd", "cdrom" ]
  }

  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

  graphics {
    type = "spice"
    listen_type = "address"
    autoport = "true"
  }

}

terraform {
 required_version = ">= 1.0"
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "0.7.0"
    }
  }
}

output "macs" {
  value = "${flatten(libvirt_domain.master.*.network_interface.0.mac)}"
}

output "id" {
  value = "${ libvirt_domain.master.*.id }"
}
