variable "region" {
  description = "Azure region for all resources"
  type        = string
  default     = "eastus"
}

variable "tags" {
  description = "Application tag for all resources"
  type        = string
  default     = "Property Manager"
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
