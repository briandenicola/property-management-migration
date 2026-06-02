output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.this.name
}

output "vm_public_ip" {
  description = "Public IP address of the legacy VM"
  value       = azurerm_public_ip.this.ip_address
}

output "rdp_connection_string" {
  description = "RDP connection command"
  value       = "mstsc /v:${azurerm_public_ip.this.ip_address}:3389"
}

output "vm_admin_username" {
  description = "VM administrator username"
  value       = var.admin_username
}

output "vm_admin_password" {
  description = "VM administrator password (generated)"
  value       = random_password.admin.result
  sensitive   = true
}

output "sql_sa_password" {
  description = "SQL Server SA password (generated)"
  value       = random_password.sql.result
  sensitive   = true
}

output "iis_url" {
  description = "URL to access the IIS-hosted application"
  value       = "http://${azurerm_public_ip.this.ip_address}"
}

output "dc_public_ip" {
  description = "Public IP of the Domain Controller"
  value       = azurerm_public_ip.dc.ip_address
}

output "dc_rdp_connection_string" {
  description = "RDP connection command for the DC"
  value       = "mstsc /v:${azurerm_public_ip.dc.ip_address}:3389"
}

output "client_public_ip" {
  description = "Public IP of the Windows client workstation"
  value       = azurerm_public_ip.client.ip_address
}

output "client_rdp_connection_string" {
  description = "RDP connection command for the client"
  value       = "mstsc /v:${azurerm_public_ip.client.ip_address}:3389"
}

output "domain_name" {
  description = "Active Directory domain FQDN"
  value       = var.domain_name
}

output "domain_admin_upn" {
  description = "Domain admin UPN for login"
  value       = "${var.admin_username}@${var.domain_name}"
}
