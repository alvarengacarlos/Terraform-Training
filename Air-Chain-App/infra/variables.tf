variable "environment" {
  description = "Set the environment"
  type        = string
  validation {
    condition     = can(regex("^(dev|prod)$", var.environment))
    error_message = "The 'environment' variable must be 'dev' or 'prod'"
  }
}

variable "my_public_ip" {
  description = "Set your public ip to access via SSH"
  type        = string
  validation {
    condition     = can(regex("^\\d+\\.\\d+\\.\\d+\\.\\d+\\/\\d+$", var.my_public_ip))
    error_message = "The 'your_public_ip' variable must be a valid IPv4 address"
  }
}

variable "aws_region" {
  description = "Set the aws region"
  type        = string
  validation {
    condition     = can(regex("^(us-east-1|us-east-2)$", var.aws_region))
    error_message = "The 'aws_region' variable must be a valid region like 'us-east-1'"
  }
}

variable "database_root_user_password" {
  description = "Set the root user database password"
  type        = string
  sensitive   = true
  validation {
    condition     = can(regex("^[^/'\"@]*$", var.database_root_user_password))
    error_message = "The password cannot contain / ' \" or @ characters"
  }
}

variable "github_personal_access_token" {
  description = "Set the github token allowing aws access the repository"
  type        = string
  sensitive   = true
}
