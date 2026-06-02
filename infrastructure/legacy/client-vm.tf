# --- Windows Client VM ---
# Domain-joined workstation for testing Windows Authentication

locals {
  client_computer_name = "pm-client01"
  client_vm_size       = "Standard_B2s"
}

resource "azurerm_network_interface" "client" {
  name                = "${local.resource_name}-client-nic"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name

  tags = {
    Application = var.tags
    Role        = "Client Workstation"
    DeployedOn  = timestamp()
  }

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.this.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_interface_security_group_association" "client" {
  network_interface_id      = azurerm_network_interface.client.id
  network_security_group_id = azurerm_network_security_group.this.id
}

resource "azurerm_windows_virtual_machine" "client" {
  name                = "${local.resource_name}-client"
  computer_name       = local.client_computer_name
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  size                = local.client_vm_size
  admin_username      = var.admin_username
  admin_password      = random_password.admin.result

  tags = {
    Application = var.tags
    Role        = "Client Workstation"
    Components  = "Windows 11; Domain-joined;"
    DeployedOn  = timestamp()
  }

  network_interface_ids = [
    azurerm_network_interface.client.id
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = 128
  }

  source_image_reference {
    publisher = "MicrosoftWindowsDesktop"
    offer     = "windows-11"
    sku       = "win11-24h2-ent"
    version   = "latest"
  }

  depends_on = [azurerm_virtual_network_dns_servers.this]
}

# Domain join is performed manually via Bastion after DC promotion completes.
# Use: Add-Computer -DomainName "bjdazure.tech" -Credential (Get-Credential) -Restart
