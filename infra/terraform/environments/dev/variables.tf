# Development Environment Variables

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "liberty-platform"
}

variable "owner" {
  description = "Owner of the resources"
  type        = string
  default     = "platform-team"
}

# VPC Configuration
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.1.0.0/16"  # Different from prod
}

variable "az_count" {
  description = "Number of availability zones to use"
  type        = number
  default     = 2
}

# Access Control
variable "allowed_ssh_cidrs" {
  description = "CIDR blocks allowed for SSH access"
  type        = list(string)
  default     = []
}

variable "allowed_web_cidrs" {
  description = "CIDR blocks allowed for web access"
  type        = list(string)
  default     = []
}

variable "alb_allowed_cidrs" {
  description = "CIDR blocks allowed for ALB access"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "ssh_key_name" {
  description = "SSH key pair name"
  type        = string
}

# Instance Types
variable "awx_instance_type" {
  description = "Instance type for AWX server"
  type        = string
  default     = "t3.medium"
}

variable "monitoring_instance_type" {
  description = "Instance type for monitoring server"
  type        = string
  default     = "t3.medium"
}

variable "liberty_instance_type" {
  description = "Instance type for Liberty servers"
  type        = string
  default     = "t3.small"
}

# Liberty Server Configuration
variable "liberty_instance_count" {
  description = "Number of Liberty server instances"
  type        = number
  default     = 1
}

variable "liberty_data_volume_size" {
  description = "Size in GB for Liberty data volume"
  type        = number
  default     = 50
}

# GitHub OIDC and Alerting
variable "create_github_oidc_provider" {
  description = "Whether to create GitHub OIDC provider for CI/CD"
  type        = bool
  default     = false
}

variable "alert_email" {
  description = "Email address for alert notifications"
  type        = string
  default     = ""
}
