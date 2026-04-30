variable "location" {
  description = "Azure region for all resources"
  type        = string
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
