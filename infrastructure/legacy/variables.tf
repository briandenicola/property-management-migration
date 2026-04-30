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

variable "admin_username" {
  description = "Administrator username for the VM"
  type        = string
  default     = "pmadmin"
}

variable "admin_password" {
  description = "Administrator password for the VM"
  type        = string
  sensitive   = true
}

variable "vm_size" {
  description = "Azure VM size"
  type        = string
  default     = "Standard_D2s_v3"
}

variable "sql_sa_password" {
  description = "SA password for SQL Server Express"
  type        = string
  sensitive   = true
}
