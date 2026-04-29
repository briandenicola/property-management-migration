output "app_service_url" {
  description = "URL of the deployed App Service"
  value       = "https://${azurerm_windows_web_app.modern.default_hostname}"
}

output "app_service_name" {
  description = "Name of the App Service (for deployment commands)"
  value       = azurerm_windows_web_app.modern.name
}

output "sql_server_fqdn" {
  description = "Fully qualified domain name of the Azure SQL Server"
  value       = azurerm_mssql_server.modern.fully_qualified_domain_name
}

output "sql_connection_string" {
  description = "Connection string for the PropertyManager database"
  value       = "Server=tcp:${azurerm_mssql_server.modern.fully_qualified_domain_name},1433;Initial Catalog=${azurerm_mssql_database.modern.name};Persist Security Info=False;User ID=${var.sql_admin_username};Password=${var.sql_admin_password};MultipleActiveResultSets=True;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
  sensitive   = true
}

output "storage_connection_string" {
  description = "Connection string for Azure Blob Storage"
  value       = azurerm_storage_account.modern.primary_connection_string
  sensitive   = true
}

output "storage_container_name" {
  description = "Name of the blob container for attachments"
  value       = azurerm_storage_container.attachments.name
}

output "application_insights_key" {
  description = "Application Insights instrumentation key"
  value       = azurerm_application_insights.modern.instrumentation_key
  sensitive   = true
}

output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.modern.name
}
