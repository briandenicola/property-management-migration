data "azuread_client_config" "current" {}

# App Registration is created manually in Azure Portal with Admin/User App Roles.
# Pass the client_id as a variable; Terraform creates a short-lived secret for Easy Auth.
data "azuread_application" "this" {
  client_id = var.entra_app_client_id
}

resource "azuread_application_password" "this" {
  application_id = data.azuread_application.this.id
  display_name   = "App Service Easy Auth"
  end_date       = timeadd(timestamp(), "168h") # 7 days
}
