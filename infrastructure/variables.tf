variable "resource_group_name" {
  description = "Name of the Azure Resource Group"
  type        = string
  default     = "rg-property-mgmt-legacy"
}

variable "location" {
  description = "Azure region for all resources"
  type        = string
  default     = "East US"
}

variable "vm_admin_username" {
  description = "Admin username for the Windows VM"
  type        = string
  default     = "pmadmin"
}

variable "vm_admin_password" {
  description = "Admin password for the Windows VM"
  type        = string
  sensitive   = true
}

variable "vm_size" {
  description = "Azure VM size (cost-effective for demo)"
  type        = string
  default     = "Standard_B2ms"
}

variable "dns_label_prefix" {
  description = "DNS label prefix for the VM public IP"
  type        = string
  default     = "propmgmt-legacy"
}

variable "sql_sa_password" {
  description = "SA password for SQL Server Express installed on the VM"
  type        = string
  sensitive   = true
}
