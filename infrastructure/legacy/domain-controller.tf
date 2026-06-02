# --- Domain Controller VM ---
# Promotes to AD DS forest root for bjdazure.tech

locals {
  dc_computer_name = "pm-dc01"
  dc_vm_size       = "Standard_B2s"
  domain_name      = var.domain_name
  domain_netbios   = upper(split(".", var.domain_name)[0])
  dc_private_ip    = cidrhost(local.compute_subnet_cidir, 10)
}

resource "azurerm_public_ip" "dc" {
  name                = "${local.resource_name}-dc-pip"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = {
    Application = var.tags
    Role        = "Domain Controller"
    DeployedOn  = timestamp()
  }
}

resource "azurerm_network_interface" "dc" {
  name                = "${local.resource_name}-dc-nic"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name

  tags = {
    Application = var.tags
    Role        = "Domain Controller"
    DeployedOn  = timestamp()
  }

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.this.id
    private_ip_address_allocation = "Static"
    private_ip_address            = local.dc_private_ip
    public_ip_address_id          = azurerm_public_ip.dc.id
  }
}

resource "azurerm_network_interface_security_group_association" "dc" {
  network_interface_id      = azurerm_network_interface.dc.id
  network_security_group_id = azurerm_network_security_group.this.id
}

resource "azurerm_windows_virtual_machine" "dc" {
  name                = "${local.resource_name}-dc"
  computer_name       = local.dc_computer_name
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  size                = local.dc_vm_size
  admin_username      = var.admin_username
  admin_password      = random_password.admin.result

  tags = {
    Application = var.tags
    Role        = "Domain Controller"
    Components  = "AD DS; DNS;"
    DeployedOn  = timestamp()
  }

  network_interface_ids = [
    azurerm_network_interface.dc.id
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

resource "azurerm_virtual_machine_extension" "dc_promote" {
  name                 = "promote-domain-controller"
  virtual_machine_id   = azurerm_windows_virtual_machine.dc.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"

  settings = jsonencode({
    commandToExecute = join(" ", [
      "powershell -ExecutionPolicy Bypass -Command \"",
      "Install-WindowsFeature -Name AD-Domain-Services, DNS -IncludeManagementTools;",
      "Import-Module ADDSDeployment;",
      "$pw = ConvertTo-SecureString '${random_password.admin.result}' -AsPlainText -Force;",
      "Install-ADDSForest",
      "-DomainName '${local.domain_name}'",
      "-DomainNetbiosName '${local.domain_netbios}'",
      "-ForestMode 'WinThreshold'",
      "-DomainMode 'WinThreshold'",
      "-InstallDns:$$true",
      "-SafeModeAdministratorPassword $pw",
      "-DatabasePath 'C:\\Windows\\NTDS'",
      "-LogPath 'C:\\Windows\\NTDS'",
      "-SysvolPath 'C:\\Windows\\SYSVOL'",
      "-NoRebootOnCompletion:$$false",
      "-Force:$$true",
      "\""
    ])
  })

  tags = {
    Application = var.tags
    DeployedOn  = timestamp()
  }

  depends_on = [azurerm_windows_virtual_machine.dc]
}

# Update VNet DNS to point to DC after promotion
resource "azurerm_virtual_network_dns_servers" "this" {
  virtual_network_id = azurerm_virtual_network.this.id
  dns_servers        = [local.dc_private_ip]

  depends_on = [azurerm_virtual_machine_extension.dc_promote]
}
