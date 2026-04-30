provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location

  tags = {
    environment = "legacy-demo"
    project     = "property-management"
    purpose     = "lift-and-shift-baseline"
  }
}
