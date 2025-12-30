# Security Groups Module Outputs

output "bastion_security_group_id" {
  description = "Security group ID for bastion host"
  value       = aws_security_group.bastion.id
}

output "awx_security_group_id" {
  description = "Security group ID for AWX server"
  value       = aws_security_group.awx.id
}

output "monitoring_security_group_id" {
  description = "Security group ID for monitoring stack"
  value       = aws_security_group.monitoring.id
}

output "liberty_security_group_id" {
  description = "Security group ID for Liberty servers"
  value       = aws_security_group.liberty.id
}

output "alb_security_group_id" {
  description = "Security group ID for Application Load Balancer"
  value       = aws_security_group.alb.id
}

output "security_group_ids" {
  description = "Map of all security group IDs"
  value = {
    bastion    = aws_security_group.bastion.id
    awx        = aws_security_group.awx.id
    monitoring = aws_security_group.monitoring.id
    liberty    = aws_security_group.liberty.id
    alb        = aws_security_group.alb.id
  }
}
