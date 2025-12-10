variable "rg_name" {
  description = "Name of the resource group"
  type        = string
}

variable "ssh_pub_key_path" {
  description = "Path to the SSH public key used for VM access"
  type        = string
}

variable "public_ip" {
  description = "Your public IP address"
  type        = string
}
