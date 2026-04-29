variable "resource_group_name" {
  description = "Name of the resource group for legacy infrastructure"
  type        = string
  default     = "pm-legacy-rg"
}

variable "location" {
  description = "Azure region for all resources"
  type        = string
  default     = "eastus2"
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

variable "allowed_rdp_ip" {
  description = "IP address allowed to RDP into the VM (CIDR notation, e.g. 203.0.113.50/32)"
  type        = string
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
