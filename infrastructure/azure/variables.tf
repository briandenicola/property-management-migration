variable "resource_group_name" {
  description = "Name of the resource group for modern PaaS infrastructure"
  type        = string
  default     = "pm-modern-rg"
}

variable "location" {
  description = "Azure region for all resources"
  type        = string
  default     = "eastus2"
}

variable "app_name_prefix" {
  description = "Prefix for all resource names (must be globally unique for App Service and Storage)"
  type        = string
  default     = "pm-modern"
}

variable "sql_admin_username" {
  description = "Administrator username for Azure SQL Server"
  type        = string
  default     = "sqladmin"
}

variable "sql_admin_password" {
  description = "Administrator password for Azure SQL Server"
  type        = string
  sensitive   = true
}

variable "sql_sku" {
  description = "Azure SQL Database SKU (service tier)"
  type        = string
  default     = "S0"
}

variable "allowed_ip_addresses" {
  description = "List of IP addresses allowed to access Azure SQL directly (for development/migration)"
  type        = list(string)
  default     = []
}
