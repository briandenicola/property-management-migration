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

output "iis_url" {
  description = "URL to access the IIS-hosted application"
  value       = "http://${azurerm_public_ip.this.ip_address}"
}
