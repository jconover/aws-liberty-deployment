# EC2 Instance Module Variables

variable "name" {
  description = "Name of the EC2 instance"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "role" {
  description = "Role of the instance (awx, monitoring, liberty, bastion)"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.medium"
}

variable "ami_id" {
  description = "AMI ID to use. If null, latest Amazon Linux 2023 will be used"
  type        = string
  default     = null
}

variable "ami_owners" {
  description = "A list of AWS account IDs that own the AMI. Used to search for public AMIs."
  type        = list(string)
  default     = ["amazon"]
}

variable "use_amazon_linux_2" {
  description = "Use Amazon Linux 2 instead of Amazon Linux 2023"
  type        = bool
  default     = false
}

variable "subnet_id" {
  description = "Subnet ID where the instance will be launched"
  type        = string
}

variable "security_group_ids" {
  description = "List of security group IDs to attach"
  type        = list(string)
}

variable "associate_public_ip" {
  description = "Associate a public IP address"
  type        = bool
  default     = false
}

variable "key_name" {
  description = "SSH key pair name"
  type        = string
  default     = null
}

variable "iam_instance_profile" {
  description = "IAM instance profile name"
  type        = string
  default     = null
}

# Root volume configuration
variable "root_volume_type" {
  description = "Root volume type"
  type        = string
  default     = "gp3"
}

variable "root_volume_size" {
  description = "Root volume size in GB"
  type        = number
  default     = 30
}

variable "delete_root_volume_on_termination" {
  description = "Delete root volume on instance termination"
  type        = bool
  default     = true
}

variable "kms_key_id" {
  description = "KMS key ID for EBS encryption"
  type        = string
  default     = null
}

# Additional volumes
variable "additional_volumes" {
  description = "List of additional EBS volumes to attach"
  type = list(object({
    device_name           = string
    volume_size           = number
    volume_type           = optional(string, "gp3")
    delete_on_termination = optional(bool, true)
  }))
  default = []
}

# User data
variable "additional_user_data" {
  description = "Additional user data script to append to default"
  type        = string
  default     = ""
}

variable "custom_user_data" {
  description = "Custom user data script (replaces default entirely)"
  type        = string
  default     = null
}

variable "user_data_replace_on_change" {
  description = "Recreate instance if user data changes"
  type        = bool
  default     = false
}

# Instance options
variable "enable_detailed_monitoring" {
  description = "Enable detailed CloudWatch monitoring"
  type        = bool
  default     = true
}

variable "enable_termination_protection" {
  description = "Enable termination protection"
  type        = bool
  default     = false
}

variable "enable_stop_protection" {
  description = "Enable stop protection"
  type        = bool
  default     = false
}

variable "cpu_credits" {
  description = "CPU credit option for burstable instances (standard or unlimited)"
  type        = string
  default     = "standard"
}

# Elastic IP
variable "create_eip" {
  description = "Create and associate an Elastic IP"
  type        = bool
  default     = false
}

# CloudWatch Alarms
variable "create_cloudwatch_alarms" {
  description = "Create CloudWatch alarms for the instance"
  type        = bool
  default     = true
}

variable "cpu_alarm_threshold" {
  description = "CPU utilization threshold for alarm"
  type        = number
  default     = 80
}

variable "alarm_actions" {
  description = "List of ARNs for alarm actions (SNS topics)"
  type        = list(string)
  default     = []
}

# DNS
variable "create_dns_record" {
  description = "Create a Route53 DNS record"
  type        = bool
  default     = false
}

variable "create_private_dns_record" {
  description = "Create a private Route53 DNS record"
  type        = bool
  default     = false
}

variable "route53_zone_id" {
  description = "Route53 hosted zone ID for public DNS"
  type        = string
  default     = null
}

variable "private_zone_id" {
  description = "Route53 private hosted zone ID"
  type        = string
  default     = null
}

variable "dns_name" {
  description = "DNS record name (defaults to instance name)"
  type        = string
  default     = null
}

variable "dns_ttl" {
  description = "DNS record TTL"
  type        = number
  default     = 300
}

# Tags
variable "tags" {
  description = "Additional tags for all resources"
  type        = map(string)
  default     = {}
}
