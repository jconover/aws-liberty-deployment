# Security Groups Module Variables

variable "project_name" {
  description = "Name of the project, used for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC where security groups will be created"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block of the VPC"
  type        = string
}

variable "allowed_ssh_cidrs" {
  description = "CIDR blocks allowed to SSH to bastion"
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for cidr in var.allowed_ssh_cidrs : can(cidrhost(cidr, 0))
    ])
    error_message = "All SSH CIDRs must be valid IPv4 CIDR blocks."
  }
}

variable "allowed_web_cidrs" {
  description = "CIDR blocks allowed to access web UIs (AWX, Grafana)"
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for cidr in var.allowed_web_cidrs : can(cidrhost(cidr, 0))
    ])
    error_message = "All web CIDRs must be valid IPv4 CIDR blocks."
  }
}

variable "alb_allowed_cidrs" {
  description = "CIDR blocks allowed to access the ALB"
  type        = list(string)
  default     = ["0.0.0.0/0"]

  validation {
    condition = alltrue([
      for cidr in var.alb_allowed_cidrs : can(cidrhost(cidr, 0))
    ])
    error_message = "All ALB CIDRs must be valid IPv4 CIDR blocks."
  }
}

variable "tags" {
  description = "Additional tags for all resources"
  type        = map(string)
  default     = {}
}
