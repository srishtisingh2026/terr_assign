terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# ─────────────────────────────
# Resource Group
# ─────────────────────────────
resource "azurerm_resource_group" "rg" {
  name     = "tf-azure-rg"
  location = "centralindia"
}

# ─────────────────────────────
# Virtual Network and Subnets
# ─────────────────────────────
resource "azurerm_virtual_network" "vnet" {
  name                = "tf-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "public" {
  name                 = "public-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_subnet" "private" {
  name                 = "private-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

# ─────────────────────────────
# Public IP (Static)
# ─────────────────────────────
resource "azurerm_public_ip" "public_ip" {
  name                = "tf-public-ip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  ip_version          = "IPv4"
  idle_timeout_in_minutes = 4
}

# ─────────────────────────────
# Network Security Group
# ─────────────────────────────
resource "azurerm_network_security_group" "nsg" {
  name                = "tf-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  # Allow HTTP
  security_rule {
    name                       = "AllowHTTP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range           = "*"
    destination_port_range      = "80"
    source_address_prefix       = "*"
    destination_address_prefix  = "*"
  }

  # Allow SSH
  security_rule {
    name                       = "AllowSSH"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range           = "*"
    destination_port_range      = "22"
    source_address_prefix       = "*"
    destination_address_prefix  = "*"
  }
}

# Associate NSG to Public Subnet
resource "azurerm_subnet_network_security_group_association" "public_assoc" {
  subnet_id                 = azurerm_subnet.public.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# ─────────────────────────────
# NICs
# ─────────────────────────────

# Public NIC (attach Public IP)
resource "azurerm_network_interface" "nic_public" {
  name                = "nic-public"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "public-nic-ip"
    subnet_id                     = azurerm_subnet.public.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public_ip.id  # ✅ added line
  }
}

# Private NIC
resource "azurerm_network_interface" "nic_private" {
  name                = "nic-private"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "private-nic-ip"
    subnet_id                     = azurerm_subnet.private.id
    private_ip_address_allocation = "Dynamic"
  }
}

# ─────────────────────────────
# SSH Key
# ─────────────────────────────
resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "private_key" {
  content  = tls_private_key.ssh_key.private_key_pem
  filename = "${path.module}/id_rsa"
}

# ─────────────────────────────
# VMs
# ─────────────────────────────

# Public VM with NGINX
resource "azurerm_linux_virtual_machine" "public_vm" {
  name                = "public-vm"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.nic_public.id]
  size                = "Standard_B1s"

  admin_username = "azureuser"
  disable_password_authentication = true

  admin_ssh_key {
    username   = "azureuser"
    public_key = tls_private_key.ssh_key.public_key_openssh
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  # cloud-init file to install nginx
  custom_data = filebase64("${path.module}/nginx-cloudinit.yml")
}

# Private VM
resource "azurerm_linux_virtual_machine" "private_vm" {
  name                = "private-vm"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.nic_private.id]
  size                = "Standard_B1s"

  admin_username = "azureuser"
  disable_password_authentication = true

  admin_ssh_key {
    username   = "azureuser"
    public_key = tls_private_key.ssh_key.public_key_openssh
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}
