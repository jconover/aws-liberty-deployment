# IAM Module Outputs

output "kms_key_id" {
  description = "ID of the KMS key"
  value       = aws_kms_key.main.id
}

output "kms_key_arn" {
  description = "ARN of the KMS key"
  value       = aws_kms_key.main.arn
}

output "kms_alias_name" {
  description = "Alias name of the KMS key"
  value       = aws_kms_alias.main.name
}

# AWX
output "awx_role_arn" {
  description = "ARN of the AWX IAM role"
  value       = aws_iam_role.awx.arn
}

output "awx_role_name" {
  description = "Name of the AWX IAM role"
  value       = aws_iam_role.awx.name
}

output "awx_instance_profile_name" {
  description = "Name of the AWX instance profile"
  value       = aws_iam_instance_profile.awx.name
}

output "awx_instance_profile_arn" {
  description = "ARN of the AWX instance profile"
  value       = aws_iam_instance_profile.awx.arn
}

# Monitoring
output "monitoring_role_arn" {
  description = "ARN of the monitoring IAM role"
  value       = aws_iam_role.monitoring.arn
}

output "monitoring_role_name" {
  description = "Name of the monitoring IAM role"
  value       = aws_iam_role.monitoring.name
}

output "monitoring_instance_profile_name" {
  description = "Name of the monitoring instance profile"
  value       = aws_iam_instance_profile.monitoring.name
}

output "monitoring_instance_profile_arn" {
  description = "ARN of the monitoring instance profile"
  value       = aws_iam_instance_profile.monitoring.arn
}

# Liberty
output "liberty_role_arn" {
  description = "ARN of the Liberty IAM role"
  value       = aws_iam_role.liberty.arn
}

output "liberty_role_name" {
  description = "Name of the Liberty IAM role"
  value       = aws_iam_role.liberty.name
}

output "liberty_instance_profile_name" {
  description = "Name of the Liberty instance profile"
  value       = aws_iam_instance_profile.liberty.name
}

output "liberty_instance_profile_arn" {
  description = "ARN of the Liberty instance profile"
  value       = aws_iam_instance_profile.liberty.arn
}

# Bastion
output "bastion_role_arn" {
  description = "ARN of the bastion IAM role"
  value       = aws_iam_role.bastion.arn
}

output "bastion_role_name" {
  description = "Name of the bastion IAM role"
  value       = aws_iam_role.bastion.name
}

output "bastion_instance_profile_name" {
  description = "Name of the bastion instance profile"
  value       = aws_iam_instance_profile.bastion.name
}

output "bastion_instance_profile_arn" {
  description = "ARN of the bastion instance profile"
  value       = aws_iam_instance_profile.bastion.arn
}

# GitHub Actions
output "github_oidc_provider_arn" {
  description = "ARN of the GitHub OIDC provider"
  value       = var.create_github_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : null
}

output "github_actions_role_arn" {
  description = "ARN of the GitHub Actions Terraform role"
  value       = var.create_github_oidc_provider ? aws_iam_role.github_actions_terraform[0].arn : null
}

# All instance profiles map
output "instance_profiles" {
  description = "Map of all instance profile names"
  value = {
    awx        = aws_iam_instance_profile.awx.name
    monitoring = aws_iam_instance_profile.monitoring.name
    liberty    = aws_iam_instance_profile.liberty.name
    bastion    = aws_iam_instance_profile.bastion.name
  }
}
