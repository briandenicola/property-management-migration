# --- Domain Join the IIS Server ---
# Joins the existing IIS/SQL VM to the AD domain after DC is promoted

resource "azurerm_virtual_machine_extension" "iis_domain_join" {
  name                 = "domain-join-iis"
  virtual_machine_id   = azurerm_windows_virtual_machine.this.id
  publisher            = "Microsoft.Compute"
  type                 = "JsonADDomainExtension"
  type_handler_version = "1.3"

  settings = jsonencode({
    Name    = local.domain_name
    OUPath  = ""
    User    = "${local.domain_name}\\${var.admin_username}"
    Restart = "true"
    Options = "3"
  })

  protected_settings = jsonencode({
    Password = random_password.admin.result
  })

  tags = {
    Application = var.tags
    DeployedOn  = timestamp()
  }

  depends_on = [
    azurerm_virtual_machine_extension.dc_promote,
    azurerm_virtual_network_dns_servers.this
  ]
}
