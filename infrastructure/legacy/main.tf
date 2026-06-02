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
  bastion_subnet_cidr  = cidrsubnet(local.vnet_cidr, 8, 3)
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
  name                            = "${local.resource_name}-subnet"
  resource_group_name             = azurerm_resource_group.this.name
  virtual_network_name            = azurerm_virtual_network.this.name
  address_prefixes                = [local.compute_subnet_cidir]
  default_outbound_access_enabled = false
}

resource "azurerm_subnet" "bastion" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [local.bastion_subnet_cidr]
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
    source_address_prefix      = "VirtualNetwork"
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
    source_address_prefix      = "VirtualNetwork"
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

  depends_on = [azurerm_virtual_network_dns_servers.this]
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

# --- IIS + SQL Server Setup via Custom Script Extension ---
resource "azurerm_virtual_machine_extension" "iis_setup" {
  name                 = "setup-legacy-server"
  virtual_machine_id   = azurerm_windows_virtual_machine.this.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"

  settings = jsonencode({
    commandToExecute = "powershell -ExecutionPolicy Unrestricted -Command \"& { $ErrorActionPreference='Stop'; $features=@('Web-Server','Web-WebServer','Web-Common-Http','Web-Static-Content','Web-Default-Doc','Web-Http-Errors','Web-App-Dev','Web-Asp-Net45','Web-Net-Ext45','Web-ISAPI-Ext','Web-ISAPI-Filter','Web-Health','Web-Http-Logging','Web-Security','Web-Filtering','Web-Windows-Auth','Web-Mgmt-Tools','Web-Mgmt-Console','NET-Framework-45-Core','NET-Framework-45-ASPNET'); Install-WindowsFeature -Name $features -IncludeManagementTools; Import-Module WebAdministration; $sitePath='C:\\inetpub\\PropertyPro'; New-Item -ItemType Directory -Path $sitePath -Force; New-Item -ItemType Directory -Path (Join-Path $sitePath 'App_Data\\Uploads\\Temp') -Force; if(!(Test-Path 'IIS:\\AppPools\\PropertyPro')){New-WebAppPool -Name 'PropertyPro'}; Set-ItemProperty 'IIS:\\AppPools\\PropertyPro' -Name 'managedRuntimeVersion' -Value 'v4.0'; Set-ItemProperty 'IIS:\\AppPools\\PropertyPro' -Name 'managedPipelineMode' -Value 'Integrated'; Remove-WebSite -Name 'Default Web Site' -ErrorAction SilentlyContinue; if(!(Get-WebSite -Name 'PropertyPro' -ErrorAction SilentlyContinue)){New-WebSite -Name 'PropertyPro' -PhysicalPath $sitePath -ApplicationPool 'PropertyPro' -Port 80 -Force}; '<html><body><h1>PropertyPro - Ready for deployment</h1></body></html>' | Out-File (Join-Path $sitePath 'index.html') -Encoding UTF8 }\""
  })

  tags = {
    Application = var.tags
    DeployedOn  = timestamp()
  }

  depends_on = [azurerm_virtual_machine_data_disk_attachment.sql_data]
}

