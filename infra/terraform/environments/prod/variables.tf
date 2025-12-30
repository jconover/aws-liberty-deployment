# Production Environment Variables

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
  default     = "10.0.0.0/16"
}

variable "az_count" {
  description = "Number of availability zones"
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
  description = "CIDR blocks allowed for web access (AWX, Grafana)"
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

# Instance Configuration
variable "awx_instance_type" {
  description = "Instance type for AWX server"
  type        = string
  default     = "t3.large"
}

variable "monitoring_instance_type" {
  description = "Instance type for monitoring server"
  type        = string
  default     = "t3.large"
}

variable "liberty_instance_type" {
  description = "Instance type for Liberty servers"
  type        = string
  default     = "t3.medium"
}

variable "liberty_instance_count" {
  description = "Number of Liberty servers"
  type        = number
  default     = 2
}

variable "liberty_data_volume_size" {
  description = "Size of Liberty data volume in GB"
  type        = number
  default     = 100
}

# GitHub OIDC
variable "create_github_oidc_provider" {
  description = "Create GitHub OIDC provider"
  type        = bool
  default     = false
}

variable "github_org" {
  description = "GitHub organization"
  type        = string
  default     = ""
}

variable "github_repo" {
  description = "GitHub repository"
  type        = string
  default     = ""
}

# Alerting
variable "alert_email" {
  description = "Email for alerts"
  type        = string
  default     = ""
}
