resource "random_id" "this" {
  byte_length = 2
}

resource "random_pet" "this" {
  length    = 1
  separator = ""
}

resource "random_integer" "vnet_cidr" {
  min = 10
  max = 250
}

resource "random_password" "sql" {
  length  = 16
  special = true
}

resource "random_password" "admin" {
  length  = 16
  special = true
}

locals {
  location             = var.location
  resource_name        = "${random_pet.this.id}-${random_id.this.dec}"
  computer_name        = substr("pm${random_id.this.hex}", 0, 15)
  vm_size              = "Standard_B2ms"
  vnet_cidr            = cidrsubnet("10.0.0.0/8", 8, random_integer.vnet_cidr.result)
  pe_subnet_cidir      = cidrsubnet(local.vnet_cidr, 8, 1)
  compute_subnet_cidir = cidrsubnet(local.vnet_cidr, 8, 2)
  home_network         = "${chomp(data.http.myip.response_body)}/32"
}

resource "azurerm_resource_group" "this" {
  name     = "${local.resource_name}_rg"
  location = local.location

  tags = {
    Application = var.tags
    Components  = "IIS; SQL Server Express;"
    DeployedOn  = timestamp()
  }
}

# --- Networking ---

resource "azurerm_virtual_network" "this" {
  name                = "${local.resource_name}-vnet"
  address_space       = [local.vnet_cidr]
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name

  tags = {
    Application = var.tags
    DeployedOn  = timestamp()
  }
}

resource "azurerm_subnet" "this" {
  name                 = "${local.resource_name}-subnet"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [local.compute_subnet_cidir]
}

resource "azurerm_public_ip" "this" {
  name                = "${local.resource_name}-pip"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = {
    Application = var.tags
    DeployedOn  = timestamp()
  }
}

resource "azurerm_network_security_group" "this" {
  name                = "${local.resource_name}-nsg"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name

  tags = {
    Application = var.tags
    DeployedOn  = timestamp()
  }

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
    source_address_prefix      = local.home_network
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface" "this" {
  name                = "${local.resource_name}-nic"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name

  tags = {
    Application = var.tags
    DeployedOn  = timestamp()
  }

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.this.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.this.id
  }
}

resource "azurerm_network_interface_security_group_association" "this" {
  network_interface_id      = azurerm_network_interface.this.id
  network_security_group_id = azurerm_network_security_group.this.id
}

# --- Virtual Machine ---

resource "azurerm_windows_virtual_machine" "this" {
  name                = "${local.resource_name}-vm"
  computer_name       = local.computer_name
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  size                = local.vm_size
  admin_username      = var.admin_username
  admin_password      = random_password.admin.result

  tags = {
    Application = var.tags
    Components  = "IIS; SQL Server Express;"
    DeployedOn  = timestamp()
  }

  network_interface_ids = [
    azurerm_network_interface.this.id
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
  name                 = "${local.resource_name}-sql-data"
  location             = azurerm_resource_group.this.location
  resource_group_name  = azurerm_resource_group.this.name
  storage_account_type = "Premium_LRS"
  create_option        = "Empty"
  disk_size_gb         = 64

  tags = {
    Application = var.tags
    DeployedOn  = timestamp()
  }
}

resource "azurerm_virtual_machine_data_disk_attachment" "sql_data" {
  managed_disk_id    = azurerm_managed_disk.sql_data.id
  virtual_machine_id = azurerm_windows_virtual_machine.this.id
  lun                = 0
  caching            = "ReadOnly"
}

# --- Custom Script Extension (IIS + SQL Server Express Setup) ---

resource "azurerm_virtual_machine_extension" "setup" {
  name                 = "${local.resource_name}-setup"
  virtual_machine_id   = azurerm_windows_virtual_machine.this.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"

  tags = {
    Application = var.tags
    DeployedOn  = timestamp()
  }

  settings = <<SETTINGS
    {
      "commandToExecute": "powershell -ExecutionPolicy Unrestricted -File setup-legacy-server.ps1 -SqlSaPassword '${random_password.sql.result}' -AdminUsername '${var.admin_username}'"
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
