# Development Environment Outputs

output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "bastion_public_ip" {
  description = "Public IP of the bastion host"
  value       = module.bastion.public_ip
}

output "awx_private_ip" {
  description = "Private IP of the AWX server"
  value       = module.awx.private_ip
}

output "liberty_private_ip" {
  description = "Private IP of the Liberty server"
  value       = module.liberty.private_ip
}

output "artifacts_bucket_name" {
  description = "Name of the artifacts S3 bucket"
  value       = aws_s3_bucket.artifacts.id
}

output "ssh_to_bastion" {
  description = "SSH command to connect to bastion"
  value       = "ssh -i ~/.ssh/${var.ssh_key_name}.pem ec2-user@${module.bastion.public_ip}"
}
