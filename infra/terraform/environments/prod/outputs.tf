# Production Environment Outputs

# VPC Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = module.vpc.vpc_cidr
}

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of private subnets"
  value       = module.vpc.private_subnet_ids
}

# Bastion
output "bastion_public_ip" {
  description = "Public IP of the bastion host"
  value       = module.bastion.public_ip
}

output "bastion_instance_id" {
  description = "Instance ID of the bastion host"
  value       = module.bastion.instance_id
}

# AWX
output "awx_private_ip" {
  description = "Private IP of the AWX server"
  value       = module.awx.private_ip
}

output "awx_instance_id" {
  description = "Instance ID of the AWX server"
  value       = module.awx.instance_id
}

# Monitoring
output "monitoring_private_ip" {
  description = "Private IP of the monitoring server"
  value       = module.monitoring.private_ip
}

output "monitoring_instance_id" {
  description = "Instance ID of the monitoring server"
  value       = module.monitoring.instance_id
}

# Liberty Servers
output "liberty_private_ips" {
  description = "Private IPs of Liberty servers"
  value       = { for k, v in module.liberty : k => v.private_ip }
}

output "liberty_instance_ids" {
  description = "Instance IDs of Liberty servers"
  value       = { for k, v in module.liberty : k => v.instance_id }
}

# Security Groups
output "security_group_ids" {
  description = "Map of security group IDs"
  value       = module.security_groups.security_group_ids
}

# IAM
output "kms_key_arn" {
  description = "ARN of the KMS key"
  value       = module.iam.kms_key_arn
}

output "instance_profiles" {
  description = "Map of instance profile names"
  value       = module.iam.instance_profiles
}

# Artifacts Bucket
output "artifacts_bucket_name" {
  description = "Name of the artifacts S3 bucket"
  value       = aws_s3_bucket.artifacts.id
}

output "artifacts_bucket_arn" {
  description = "ARN of the artifacts S3 bucket"
  value       = aws_s3_bucket.artifacts.arn
}

# Alerts
output "alerts_topic_arn" {
  description = "ARN of the SNS alerts topic"
  value       = aws_sns_topic.alerts.arn
}

# SSH Connection Commands
output "ssh_to_bastion" {
  description = "SSH command to connect to bastion"
  value       = "ssh -i ~/.ssh/${var.ssh_key_name}.pem ec2-user@${module.bastion.public_ip}"
}

output "ssh_to_awx_via_bastion" {
  description = "SSH command to connect to AWX via bastion"
  value       = "ssh -i ~/.ssh/${var.ssh_key_name}.pem -J ec2-user@${module.bastion.public_ip} ec2-user@${module.awx.private_ip}"
}
