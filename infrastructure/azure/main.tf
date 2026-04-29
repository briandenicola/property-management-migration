locals {
  common_tags = {
    project     = "property-management"
    environment = "modern"
    managed_by  = "terraform"
  }

  # Sanitize prefix for resources that don't allow hyphens
  storage_name = replace(lower(var.app_name_prefix), "-", "")
}

resource "azurerm_resource_group" "modern" {
  name     = var.resource_group_name
  location = var.location
  tags     = local.common_tags
}

# --- App Service Plan ---

resource "azurerm_service_plan" "modern" {
  name                = "${var.app_name_prefix}-plan"
  location            = azurerm_resource_group.modern.location
  resource_group_name = azurerm_resource_group.modern.name
  os_type             = "Windows"
  sku_name            = "S1"
  tags                = local.common_tags
}

# --- App Service (Windows, .NET Framework 4.6) ---

resource "azurerm_windows_web_app" "modern" {
  name                = "${var.app_name_prefix}-app"
  location            = azurerm_resource_group.modern.location
  resource_group_name = azurerm_resource_group.modern.name
  service_plan_id     = azurerm_service_plan.modern.id
  tags                = local.common_tags

  site_config {
    always_on = true

    application_stack {
      current_stack  = "dotnet"
      dotnet_version = "v4.0"
    }
  }

  app_settings = {
    "APPINSIGHTS_INSTRUMENTATIONKEY"             = azurerm_application_insights.modern.instrumentation_key
    "APPLICATIONINSIGHTS_CONNECTION_STRING"      = azurerm_application_insights.modern.connection_string
    "ApplicationInsightsAgent_EXTENSION_VERSION" = "~2"
    "BlobStorage__ConnectionString"              = azurerm_storage_account.modern.primary_connection_string
    "BlobStorage__ContainerName"                 = azurerm_storage_container.attachments.name
    "MaxFileSizeBytes"                           = "26214400"
  }

  connection_string {
    name  = "PropertyManager"
    type  = "SQLAzure"
    value = "Server=tcp:${azurerm_mssql_server.modern.fully_qualified_domain_name},1433;Initial Catalog=${azurerm_mssql_database.modern.name};Persist Security Info=False;User ID=${var.sql_admin_username};Password=${var.sql_admin_password};MultipleActiveResultSets=True;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
  }

  identity {
    type = "SystemAssigned"
  }
}

# --- Azure SQL Server ---

resource "azurerm_mssql_server" "modern" {
  name                         = "${var.app_name_prefix}-sql"
  resource_group_name          = azurerm_resource_group.modern.name
  location                     = azurerm_resource_group.modern.location
  version                      = "12.0"
  administrator_login          = var.sql_admin_username
  administrator_login_password = var.sql_admin_password
  minimum_tls_version          = "1.2"
  tags                         = local.common_tags
}

resource "azurerm_mssql_database" "modern" {
  name        = "PropertyManager"
  server_id   = azurerm_mssql_server.modern.id
  collation   = "SQL_Latin1_General_CP1_CI_AS"
  sku_name    = var.sql_sku
  max_size_gb = 2
  tags        = local.common_tags
}

# Allow Azure services to access SQL Server
resource "azurerm_mssql_firewall_rule" "allow_azure_services" {
  name             = "AllowAzureServices"
  server_id        = azurerm_mssql_server.modern.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

# Allow specified developer IPs
resource "azurerm_mssql_firewall_rule" "allow_dev_ips" {
  for_each         = toset(var.allowed_ip_addresses)
  name             = "AllowDev-${replace(each.value, ".", "-")}"
  server_id        = azurerm_mssql_server.modern.id
  start_ip_address = each.value
  end_ip_address   = each.value
}

# --- Azure Blob Storage ---

resource "azurerm_storage_account" "modern" {
  name                     = "${local.storage_name}stor"
  resource_group_name      = azurerm_resource_group.modern.name
  location                 = azurerm_resource_group.modern.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"
  tags                     = local.common_tags

  blob_properties {
    cors_rule {
      allowed_headers    = ["*"]
      allowed_methods    = ["GET", "PUT", "POST"]
      allowed_origins    = ["https://${var.app_name_prefix}-app.azurewebsites.net"]
      exposed_headers    = ["*"]
      max_age_in_seconds = 3600
    }
  }
}

resource "azurerm_storage_container" "attachments" {
  name                  = "attachments"
  storage_account_name  = azurerm_storage_account.modern.name
  container_access_type = "private"
}

# --- Application Insights ---

resource "azurerm_log_analytics_workspace" "modern" {
  name                = "${var.app_name_prefix}-law"
  location            = azurerm_resource_group.modern.location
  resource_group_name = azurerm_resource_group.modern.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = local.common_tags
}

resource "azurerm_application_insights" "modern" {
  name                = "${var.app_name_prefix}-appinsights"
  location            = azurerm_resource_group.modern.location
  resource_group_name = azurerm_resource_group.modern.name
  workspace_id        = azurerm_log_analytics_workspace.modern.id
  application_type    = "web"
  tags                = local.common_tags
}
