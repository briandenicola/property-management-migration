resource "random_id" "this" {
  byte_length = 2
}

resource "random_pet" "this" {
  length    = 1
  separator = ""
}

resource "random_password" "sql" {
  length  = 16
  special = true
}

locals {
  location      = var.location
  resource_name = "${random_pet.this.id}-${random_id.this.dec}"
  home_network  = "${chomp(data.http.myip.response_body)}/32"
  sql_sku       = "S0"
  app_plan_sku  = "S1"
  # Sanitize for resources that don't allow hyphens
  storage_name = replace(lower(local.resource_name), "-", "")
}

resource "azurerm_resource_group" "this" {
  name     = "${local.resource_name}_rg"
  location = local.location

  tags = {
    Application      = var.tags
    Components       = "App Service; Azure SQL; Blob Storage;"
    DeployedOn       = timestamp()
    SecurityControl  = "Ignore"
  }
}

# --- App Service Plan ---

resource "azurerm_service_plan" "this" {
  name                = "${local.resource_name}-plan"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  os_type             = "Windows"
  sku_name            = local.app_plan_sku

  tags = {
    Application = var.tags
    DeployedOn  = timestamp()
  }
}

# --- App Service (Windows, .NET Framework 4.6) ---

resource "azurerm_windows_web_app" "this" {
  name                = "${local.resource_name}-app"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  service_plan_id     = azurerm_service_plan.this.id

  tags = {
    Application = var.tags
    DeployedOn  = timestamp()
  }

  site_config {
    always_on = true

    application_stack {
      current_stack  = "dotnet"
      dotnet_version = "v4.0"
    }
  }

  app_settings = {
    "APPINSIGHTS_INSTRUMENTATIONKEY"             = azurerm_application_insights.this.instrumentation_key
    "APPLICATIONINSIGHTS_CONNECTION_STRING"      = azurerm_application_insights.this.connection_string
    "ApplicationInsightsAgent_EXTENSION_VERSION" = "~2"
    "BlobStorage__ServiceUri"                    = azurerm_storage_account.this.primary_blob_endpoint
    "BlobStorage__ContainerName"                 = azurerm_storage_container.attachments.name
    "MaxFileSizeBytes"                           = "26214400"
  }

  connection_string {
    name  = "PropertyManager"
    type  = "SQLAzure"
    value = "Server=tcp:${azurerm_mssql_server.this.fully_qualified_domain_name},1433;Initial Catalog=${azurerm_mssql_database.this.name};Persist Security Info=False;User ID=${var.sql_admin_username};Password=${random_password.sql.result};MultipleActiveResultSets=True;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
  }

  identity {
    type = "SystemAssigned"
  }
}

# --- Azure SQL Server ---

resource "azurerm_mssql_server" "this" {
  name                         = "${local.resource_name}-sql"
  resource_group_name          = azurerm_resource_group.this.name
  location                     = azurerm_resource_group.this.location
  version                      = "12.0"
  administrator_login          = var.sql_admin_username
  administrator_login_password = random_password.sql.result
  minimum_tls_version          = "1.2"

  tags = {
    Application = var.tags
    DeployedOn  = timestamp()
  }
}

resource "azurerm_mssql_database" "this" {
  name        = "PropertyManager"
  server_id   = azurerm_mssql_server.this.id
  collation   = "SQL_Latin1_General_CP1_CI_AS"
  sku_name    = local.sql_sku
  max_size_gb = 2

  tags = {
    Application = var.tags
    DeployedOn  = timestamp()
  }
}

# Allow Azure services to access SQL Server
resource "azurerm_mssql_firewall_rule" "allow_azure_services" {
  name             = "AllowAzureServices"
  server_id        = azurerm_mssql_server.this.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

# Allow home network to access SQL Server
resource "azurerm_mssql_firewall_rule" "allow_home" {
  name             = "AllowHomeNetwork"
  server_id        = azurerm_mssql_server.this.id
  start_ip_address = chomp(data.http.myip.response_body)
  end_ip_address   = chomp(data.http.myip.response_body)
}

# --- Azure Blob Storage ---

resource "azurerm_storage_account" "this" {
  name                      = "${local.storage_name}stor"
  resource_group_name       = azurerm_resource_group.this.name
  location                  = azurerm_resource_group.this.location
  account_tier              = "Standard"
  account_replication_type  = "LRS"
  min_tls_version           = "TLS1_2"
  shared_access_key_enabled = false

  tags = {
    Application = var.tags
    DeployedOn  = timestamp()
  }

  blob_properties {
    cors_rule {
      allowed_headers    = ["*"]
      allowed_methods    = ["GET", "PUT", "POST"]
      allowed_origins    = ["https://${local.resource_name}-app.azurewebsites.net"]
      exposed_headers    = ["*"]
      max_age_in_seconds = 3600
    }
  }
}

resource "azurerm_storage_container" "attachments" {
  name                  = "attachments"
  storage_account_name  = azurerm_storage_account.this.name
  container_access_type = "private"
}

# Grant App Service managed identity access to blob storage
resource "azurerm_role_assignment" "app_storage_blob" {
  scope                = azurerm_storage_account.this.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_windows_web_app.this.identity[0].principal_id
}

# --- Application Insights ---

resource "azurerm_log_analytics_workspace" "this" {
  name                = "${local.resource_name}-law"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "PerGB2018"
  retention_in_days   = 30

  tags = {
    Application = var.tags
    DeployedOn  = timestamp()
  }
}

resource "azurerm_application_insights" "this" {
  name                = "${local.resource_name}-appinsights"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  workspace_id        = azurerm_log_analytics_workspace.this.id
  application_type    = "web"

  tags = {
    Application = var.tags
    DeployedOn  = timestamp()
  }
}
