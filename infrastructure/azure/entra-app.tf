data "azuread_client_config" "current" {}

resource "random_uuid" "entra_app_role_admin" {}

resource "random_uuid" "entra_app_role_user" {}

resource "azuread_application" "this" {
  display_name     = "${local.resource_name}-propertymanager"
  sign_in_audience = "AzureADMyOrg"

  app_role {
    allowed_member_types = ["User"]
    description          = "PropertyPro administrators"
    display_name         = "Admin"
    enabled              = true
    id                   = random_uuid.entra_app_role_admin.result
    value                = "Admin"
  }

  app_role {
    allowed_member_types = ["User"]
    description          = "PropertyPro users"
    display_name         = "User"
    enabled              = true
    id                   = random_uuid.entra_app_role_user.result
    value                = "User"
  }

  web {
    redirect_uris = ["https://${local.resource_name}-app.azurewebsites.net/.auth/login/aad/callback"]
  }

  optional_claims {
    id_token {
      name = "email"
    }

    id_token {
      name = "groups"
    }
  }
}

resource "azuread_service_principal" "this" {
  client_id = azuread_application.this.client_id
}

resource "azuread_application_password" "this" {
  application_id = azuread_application.this.id
  display_name   = "App Service Easy Auth"
}
