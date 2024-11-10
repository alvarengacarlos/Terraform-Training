variable "project_name" {
  description = "Used to set the project name"
  type        = string
  nullable    = false
}

variable "adm_email_addr" {
  description = "Administrator email that will receive the notification"
  type        = string
  nullable    = false
  validation {
    condition     = can(regex("^\\S+@\\S+\\.\\S+$", var.adm_email_addr))
    error_message = "The email address is invalid"
  }
}