output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.this.name
}

output "vm_private_ip" {
  description = "Private IP address of the IIS VM"
  value       = azurerm_network_interface.this.private_ip_address
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

output "bastion_name" {
  description = "Azure Bastion host name (use Azure Portal to connect)"
  value       = azurerm_bastion_host.this.name
}

output "dc_private_ip" {
  description = "Private IP of the Domain Controller"
  value       = local.dc_private_ip
}

output "client_private_ip" {
  description = "Private IP of the Windows client workstation"
  value       = azurerm_network_interface.client.private_ip_address
}

output "domain_name" {
  description = "Active Directory domain FQDN"
  value       = var.domain_name
}

output "domain_admin_upn" {
  description = "Domain admin UPN for login"
  value       = "${var.admin_username}@${var.domain_name}"
}

output "iis_vm_id" {
  description = "Resource ID of the IIS VM"
  value       = azurerm_windows_virtual_machine.this.id
}

output "dc_vm_id" {
  description = "Resource ID of the Domain Controller VM"
  value       = azurerm_windows_virtual_machine.dc.id
}

output "client_vm_id" {
  description = "Resource ID of the Windows client VM"
  value       = azurerm_windows_virtual_machine.client.id
}
