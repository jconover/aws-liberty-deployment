# Backend Bootstrap Variables

variable "aws_region" {
  description = "AWS region for state bucket"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name, used for resource naming"
  type        = string
  default     = "liberty-platform"
}
