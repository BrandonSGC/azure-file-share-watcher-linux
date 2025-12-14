variable "rg_name" {
  description = "Name of the resource group"
  type        = string
}

variable "vm_count" {
  description = "Number of VMs to create"
  type        = number
  default     = 2
}

variable "public_ip" {
  description = "Your public IP address"
  type        = string
}

variable "vm_username" {
  description = "Username for the VM"
  type        = string
}

variable "ssh_pub_key_path" {
  description = "Path to the SSH public key used for VM access"
  type        = string
}

variable "ssh_priv_key_path" {
  description = "Path to the SSH private key used for VM access"
  type        = string
}
