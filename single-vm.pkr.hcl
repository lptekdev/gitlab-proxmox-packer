packer {
  required_plugins {
  name = {
      version = ">= 1.2.2"
      source  = "github.com/hashicorp/proxmox"
    }
    ansible = {
      version = "~> 1"
      source = "github.com/hashicorp/ansible"
    }
  }
}

variable "app_source_dir" {
  type        = string
  description = "Path to the application source directory"
}


variable "ca_host" {
  type        = string
  description = "Host SSH CA"
}

variable "vm_name" {
  type        = string
  description = "The vm name"
}

variable "vlan" {
  type        = string
  description = "The network vlan"
  default = ""

}

variable "network" {
  type        = string
  description = "The network name, could a SDN VNET or a bridge"
}

variable "pve_url" {
  type        = string
  description = "The Proxmox API url (eg: https://pve_ip_fqdn:8006/api2/json)"
}

variable "pve_user" {
  type        = string
  description = "Proxmox user (eg: root@pam)"
}

variable "pve_password" {
  type        = string
  description = "Password for the proxmox user"
}

variable "pve_node" {
  type        = string
  description = "The Proxmox node"
}

variable "storage_pool" {
  type        = string
  description = "Proxmox storage pool"
  default = "SAS-10K"
}

variable "iso_storage_pool" {
  type        = string
  description = "Proxmox ISO storage pool"
  default = "NFS-truenas02"
}

variable "template_to_clone" {
  type        = string
  description = "the template name to be cloned"
  default = "ubuntu24-tmp"
}



source "proxmox-clone" "single-vm" {
  clone_vm                 = "${var.template_to_clone}"
  cores                    = 1
  insecure_skip_tls_verify = true
  memory                   = 4096
  network_adapters  {
    bridge = "${var.network}"
    model  = "virtio"
    vlan_tag = "${var.vlan}"
  }
  
  network_adapters  {
    bridge = "${var.network}"
    model  = "virtio"
    vlan_tag = "${var.vlan}"
  }
  node                 = "${var.pve_node}"
  username             = "${var.pve_user}"
  password             = "${var.pve_password}"
  proxmox_url          = "${var.pve_url}"
  sockets              = 4
  ssh_username         = "ansible_automation" # this is the 2-day operations user
  ssh_timeout          = "10m"
  ssh_private_key_file = "ansible_automation" # this is the 2-day operations user user SSH private key 
  vm_name         = var.vm_name
  scsi_controller = "virtio-scsi-single"
  machine = "q35"
  qemu_agent = "true"
  cpu_type = "host"
  cloud_init = false
  full_clone = true
  additional_iso_files {
    type = "ide"
    device = "ide2"
    cd_files = ["./cloud-init/user-data","./cloud-init/meta-data","./cloud-init/network-config"]
    cd_label = "cidata"
    iso_storage_pool = "${var.iso_storage_pool}"
  } 

  boot = "order=ide2;scsi0;net0"
  pause_before_connecting = "30s"
  
  # additional disk (can be removed)
  disks {
    disk_size         = "100G"
    storage_pool      = "${var.storage_pool}"
    type              = "scsi"
    discard            = "true"  
  }
  task_timeout = "10m"
}

build {
  sources = ["source.proxmox-clone.single-vm"]
provisioner "ansible" {
    extra_arguments = [
      "-vv",
      "-e","app_source_dir=${var.app_source_dir}",
      "-e","ca_host=${var.ca_host}",
      "-e","vm_name=${var.vm_name}",
    ]
    ansible_env_vars = [ "ANSIBLE_HOST_KEY_CHECKING=False" ]
    use_proxy     = false
    
    playbook_file = "./ansible/main-playbook.yml"
    timeout = "10m"
    user = "ansible_automation" #this is the 2-day operations user
  }
}

