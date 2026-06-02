variable "location" {
  description = "Azure region for all resources"
  type        = string
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

variable "entra_app_client_id" {
  description = "Client ID of the manually-created Entra ID App Registration for Easy Auth"
  type        = string
}
