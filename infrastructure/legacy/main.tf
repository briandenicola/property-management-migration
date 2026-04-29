locals {
  common_tags = {
    project     = "property-management"
    environment = "legacy"
    managed_by  = "terraform"
  }
}

resource "azurerm_resource_group" "legacy" {
  name     = var.resource_group_name
  location = var.location
  tags     = local.common_tags
}

# --- Networking ---

resource "azurerm_virtual_network" "legacy" {
  name                = "pm-legacy-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.legacy.location
  resource_group_name = azurerm_resource_group.legacy.name
  tags                = local.common_tags
}

resource "azurerm_subnet" "legacy" {
  name                 = "pm-legacy-subnet"
  resource_group_name  = azurerm_resource_group.legacy.name
  virtual_network_name = azurerm_virtual_network.legacy.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_public_ip" "legacy" {
  name                = "pm-legacy-pip"
  location            = azurerm_resource_group.legacy.location
  resource_group_name = azurerm_resource_group.legacy.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.common_tags
}

resource "azurerm_network_security_group" "legacy" {
  name                = "pm-legacy-nsg"
  location            = azurerm_resource_group.legacy.location
  resource_group_name = azurerm_resource_group.legacy.name
  tags                = local.common_tags

  security_rule {
    name                       = "Allow-HTTP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-HTTPS"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-RDP"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = var.allowed_rdp_ip
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface" "legacy" {
  name                = "pm-legacy-nic"
  location            = azurerm_resource_group.legacy.location
  resource_group_name = azurerm_resource_group.legacy.name
  tags                = local.common_tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.legacy.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.legacy.id
  }
}

resource "azurerm_network_interface_security_group_association" "legacy" {
  network_interface_id      = azurerm_network_interface.legacy.id
  network_security_group_id = azurerm_network_security_group.legacy.id
}

# --- Virtual Machine ---

resource "azurerm_windows_virtual_machine" "legacy" {
  name                = "pm-legacy-vm"
  resource_group_name = azurerm_resource_group.legacy.name
  location            = azurerm_resource_group.legacy.location
  size                = var.vm_size
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  tags                = local.common_tags

  network_interface_ids = [
    azurerm_network_interface.legacy.id
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = 128
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter"
    version   = "latest"
  }
}

# --- Data Disk for SQL Server ---

resource "azurerm_managed_disk" "sql_data" {
  name                 = "pm-legacy-sql-data"
  location             = azurerm_resource_group.legacy.location
  resource_group_name  = azurerm_resource_group.legacy.name
  storage_account_type = "Premium_LRS"
  create_option        = "Empty"
  disk_size_gb         = 64
  tags                 = local.common_tags
}

resource "azurerm_virtual_machine_data_disk_attachment" "sql_data" {
  managed_disk_id    = azurerm_managed_disk.sql_data.id
  virtual_machine_id = azurerm_windows_virtual_machine.legacy.id
  lun                = 0
  caching            = "ReadOnly"
}

# --- Custom Script Extension (IIS + SQL Server Express Setup) ---

resource "azurerm_virtual_machine_extension" "setup" {
  name                 = "pm-legacy-setup"
  virtual_machine_id   = azurerm_windows_virtual_machine.legacy.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"
  tags                 = local.common_tags

  settings = <<SETTINGS
    {
      "commandToExecute": "powershell -ExecutionPolicy Unrestricted -File setup-legacy-server.ps1 -SqlSaPassword '${var.sql_sa_password}' -AdminUsername '${var.admin_username}'"
    }
SETTINGS

  protected_settings = <<PROTECTED
    {
      "fileUris": ["https://raw.githubusercontent.com/placeholder/setup-legacy-server.ps1"]
    }
PROTECTED

  depends_on = [azurerm_virtual_machine_data_disk_attachment.sql_data]

  lifecycle {
    ignore_changes = [settings, protected_settings]
  }
}
