variable "rg_name" {
  description = "Name of the resource group"
  type        = string
}

variable "public_ip" {
  description = "Your public IP address"
  type        = string
}

variable "vm_username" {
  description = "Username for the VM"
  type        = string
}

# variable "ips_list" {
#   description = "List of IPs to create"
#   type        = list(string)
#   default     = ["ip-test-1", "ip-test-2", "ip-test-3"]
# }

variable "ssh_pub_key_path" {
  description = "Path to the SSH public key used for VM access"
  type        = string
}
