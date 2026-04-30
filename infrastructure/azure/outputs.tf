output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.this.name
}

output "app_service_url" {
  description = "URL of the deployed App Service"
  value       = "https://${azurerm_windows_web_app.this.default_hostname}"
}

output "app_service_name" {
  description = "Name of the App Service (for deployment commands)"
  value       = azurerm_windows_web_app.this.name
}

output "sql_server_fqdn" {
  description = "Fully qualified domain name of the Azure SQL Server"
  value       = azurerm_mssql_server.this.fully_qualified_domain_name
}

output "sql_admin_password" {
  description = "Azure SQL administrator password (generated)"
  value       = random_password.sql.result
  sensitive   = true
}

output "sql_connection_string" {
  description = "Connection string for the PropertyManager database"
  value       = "Server=tcp:${azurerm_mssql_server.this.fully_qualified_domain_name},1433;Initial Catalog=${azurerm_mssql_database.this.name};Persist Security Info=False;User ID=${var.sql_admin_username};Password=${random_password.sql.result};MultipleActiveResultSets=True;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
  sensitive   = true
}

output "storage_connection_string" {
  description = "Connection string for Azure Blob Storage"
  value       = azurerm_storage_account.this.primary_connection_string
  sensitive   = true
}

output "storage_container_name" {
  description = "Name of the blob container for attachments"
  value       = azurerm_storage_container.attachments.name
}

output "application_insights_key" {
  description = "Application Insights instrumentation key"
  value       = azurerm_application_insights.this.instrumentation_key
  sensitive   = true
}
