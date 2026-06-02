# --- NAT Gateway ---
# Provides explicit outbound internet access for VMs in the private compute subnet.
# Required for VM extensions, Windows Updates, and package downloads.

resource "azurerm_public_ip" "nat" {
  name                = "${local.resource_name}-nat-pip"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = {
    Application = var.tags
    Role        = "NAT Gateway"
    DeployedOn  = timestamp()
  }
}

resource "azurerm_nat_gateway" "this" {
  name                = "${local.resource_name}-natgw"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  sku_name            = "Standard"

  tags = {
    Application = var.tags
    Role        = "NAT Gateway"
    DeployedOn  = timestamp()
  }
}

resource "azurerm_nat_gateway_public_ip_association" "this" {
  nat_gateway_id       = azurerm_nat_gateway.this.id
  public_ip_address_id = azurerm_public_ip.nat.id
}

resource "azurerm_subnet_nat_gateway_association" "compute" {
  subnet_id      = azurerm_subnet.this.id
  nat_gateway_id = azurerm_nat_gateway.this.id
}
