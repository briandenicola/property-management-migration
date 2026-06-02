# --- Azure Bastion ---
# Provides secure RDP/SSH access to all VMs without public IPs

resource "azurerm_public_ip" "bastion" {
  name                = "${local.resource_name}-bastion-pip"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = {
    Application = var.tags
    Role        = "Bastion"
    DeployedOn  = timestamp()
  }
}

resource "azurerm_bastion_host" "this" {
  name                = "${local.resource_name}-bastion"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "Basic"

  ip_configuration {
    name                 = "bastion-ip-config"
    subnet_id            = azurerm_subnet.bastion.id
    public_ip_address_id = azurerm_public_ip.bastion.id
  }

  tags = {
    Application = var.tags
    Role        = "Bastion"
    DeployedOn  = timestamp()
  }
}
