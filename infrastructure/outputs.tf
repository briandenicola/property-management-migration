output "vm_public_ip" {
  description = "Public IP address of the legacy property management VM"
  value       = azurerm_public_ip.main.ip_address
}

output "vm_dns_name" {
  description = "Fully qualified DNS name for the VM"
  value       = azurerm_public_ip.main.fqdn
}

output "vm_admin_username" {
  description = "Admin username for RDP access"
  value       = var.vm_admin_username
}

output "sql_connection_string" {
  description = "SQL Server connection string for the property management database"
  value       = "Server=${azurerm_public_ip.main.fqdn};Database=PropertyManagement;User Id=sa;Password=<sql_sa_password>;TrustServerCertificate=True;"
  sensitive   = true
}

output "web_deploy_url" {
  description = "Web Deploy endpoint for publishing the application"
  value       = "https://${azurerm_public_ip.main.fqdn}:8172/msdeploy.axd"
}

output "app_url" {
  description = "URL to access the property management application"
  value       = "http://${azurerm_public_ip.main.fqdn}"
}
