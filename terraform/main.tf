terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "0.7.1"
    }
  }
}

provider "libvirt" {
  uri = "qemu:///system"
}

resource "libvirt_volume" "ubuntu_image" {
  name   = "ubuntu-22.04-server-cloudimg-amd64.img"
  source = "https://cloud-images.ubuntu.com/releases/22.04/release/ubuntu-22.04-server-cloudimg-amd64.img"
  pool   = "default"
  format = "qcow2"
}

data "template_file" "user_data" {
  template = file("${path.module}/cloud-init.yaml")
  vars     = { ssh_key = file("~/.ssh/id_rsa.pub") }
}

locals {
  vms = {
    nginx1   = { name = "nginx-1",   mem = 1024, cpu = 1 }
    nginx2   = { name = "nginx-2",   mem = 1024, cpu = 1 }
    backend1 = { name = "backend-1", mem = 2048, cpu = 2 }
    backend2 = { name = "backend-2", mem = 2048, cpu = 2 }
    db       = { name = "db-1",      mem = 2048, cpu = 2 }
    iscsi    = { name = "iscsi-target", mem = 1024, cpu = 1 }
  }
}

resource "libvirt_volume" "disk" {
  for_each       = local.vms
  name           = "${each.key}-disk.qcow2"
  base_volume_id = libvirt_volume.ubuntu_image.id
  pool           = "default"
  size           = 10737418240
}

# Дополнительный диск для iSCSI-target
resource "libvirt_volume" "iscsi_storage" {
  name   = "iscsi-storage.qcow2"
  pool   = "default"
  size   = 5368709120  # 5 ГБ
  format = "qcow2"
}

resource "libvirt_cloudinit_disk" "init" {
  for_each  = local.vms
  name      = "${each.key}-cloudinit.iso"
  pool      = "default"
  user_data = data.template_file.user_data.rendered
}

resource "libvirt_domain" "vm" {
  for_each  = local.vms
  name      = each.value.name
  memory    = each.value.mem
  vcpu      = each.value.cpu
  cloudinit = libvirt_cloudinit_disk.init[each.key].id

  network_interface {
    network_name = "default"
    wait_for_lease = true
  }

  disk {
    volume_id = libvirt_volume.disk[each.key].id
  }

  # Дополнительный диск для iscsi-target
  dynamic "disk" {
    for_each = each.key == "iscsi" ? [1] : []
    content {
      volume_id = libvirt_volume.iscsi_storage.id
    }
  }

  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }
}
