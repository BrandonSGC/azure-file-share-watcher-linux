# Resource Group
resource "azurerm_resource_group" "rg" {
  location = "canadacentral"
  name     = var.rg_name
}

# Storage Account
resource "azurerm_storage_account" "stg_account" {
  name                      = "stgaccntlnxprjctbgc"
  resource_group_name       = azurerm_resource_group.rg.name
  location                  = azurerm_resource_group.rg.location
  account_tier              = "Standard"
  account_replication_type  = "LRS"
  shared_access_key_enabled = true
}

# File Share
resource "azurerm_storage_share" "fileshare" {
  name               = "filesharelnxprjct"
  storage_account_id = azurerm_storage_account.stg_account.id
  quota              = 50
}

# Virtual Network
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-lnx-prjct"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Subnet
resource "azurerm_subnet" "subnet" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Public IP
resource "azurerm_public_ip" "public_ip" {
  count               = var.vm_count
  name                = "public-ip-vm-${count.index}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Static"
}

# Network Interface Card
resource "azurerm_network_interface" "nic" {
  count               = var.vm_count
  name                = "nic-vm-${count.index}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public_ip[count.index].id
  }
}

# Network Security Group
resource "azurerm_network_security_group" "nsg" {
  name                = "nsg_lnx_prjct"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Network Security Rule
resource "azurerm_network_security_rule" "nsg_ssh_rule" {
  name                        = "allow_ssh_from_my_ip"
  description                 = "Allow SSH from my public IP only"
  access                      = "Allow"
  priority                    = 100
  direction                   = "Inbound"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = var.public_ip
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.nsg.name
}

# Associate NSG with NIC
resource "azurerm_network_interface_security_group_association" "nsg_nic_association" {
  count                     = var.vm_count
  network_interface_id      = azurerm_network_interface.nic[count.index].id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# Associate NSG with Subnet
resource "azurerm_subnet_network_security_group_association" "nsg_subnet_association" {
  subnet_id                 = azurerm_subnet.subnet.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# Linux Virtual Machine
resource "azurerm_linux_virtual_machine" "vm" {
  count               = var.vm_count
  name                = "vm-${count.index}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_D2ds_v5"

  admin_username                  = var.vm_username
  disable_password_authentication = true

  network_interface_ids = [
    azurerm_network_interface.nic[count.index].id,
  ]

  admin_ssh_key {
    username   = var.vm_username
    public_key = file(var.ssh_pub_key_path)
  }

  os_disk {
    name                 = "os-disk-vm-${count.index}"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 30
  }

  source_image_reference {
    publisher = "canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }
}


# OUTPUTS

# VM Public IP
output "vms_public_ips" {
  description = "Public IP addresses of the VMs"
  value       = azurerm_public_ip.public_ip[*].ip_address
}

# Storage account name
output "storage_account_name" {
  value = azurerm_storage_account.stg_account.name
}

# Storage account key (sensitive)
output "storage_account_key" {
  value     = azurerm_storage_account.stg_account.primary_access_key
  sensitive = true
}

# File share name
output "file_share_name" {
  value = azurerm_storage_share.fileshare.name
}

# Mount directory
output "mount_dir" {
  value = "/media/az-linux-files"
}

# Generate Ansible variable file with storage details
resource "local_file" "ansible_vars" {
  content = <<EOT
storage_account_name: "${azurerm_storage_account.stg_account.name}"
storage_account_key: "${azurerm_storage_account.stg_account.primary_access_key}"
file_share_name: "${azurerm_storage_share.fileshare.name}"
mount_dir: "/media/az-linux-files"
EOT

  filename = "${path.module}/../ansible/vars/all.yml"
}

# Generate Ansible inventory file
resource "local_file" "ansible_inventory" {
  filename = "${path.module}/../ansible/inventory.ini"

  content = <<EOF
[linux]
%{for idx, ip in azurerm_public_ip.public_ip[*].ip_address~}
vm-${idx} ansible_host=${ip} ansible_user=${var.vm_username} ansible_ssh_private_key_file=${var.ssh_priv_key_path}
%{endfor~}
EOF
}
