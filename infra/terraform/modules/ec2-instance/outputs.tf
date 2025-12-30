# EC2 Instance Module Outputs

output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.main.id
}

output "instance_arn" {
  description = "ARN of the EC2 instance"
  value       = aws_instance.main.arn
}

output "private_ip" {
  description = "Private IP address of the instance"
  value       = aws_instance.main.private_ip
}

output "public_ip" {
  description = "Public IP address of the instance"
  value       = var.create_eip ? aws_eip.main[0].public_ip : aws_instance.main.public_ip
}

output "private_dns" {
  description = "Private DNS name of the instance"
  value       = aws_instance.main.private_dns
}

output "public_dns" {
  description = "Public DNS name of the instance"
  value       = aws_instance.main.public_dns
}

output "availability_zone" {
  description = "Availability zone of the instance"
  value       = aws_instance.main.availability_zone
}

output "eip_id" {
  description = "Elastic IP ID (if created)"
  value       = var.create_eip ? aws_eip.main[0].id : null
}

output "eip_public_ip" {
  description = "Elastic IP public address (if created)"
  value       = var.create_eip ? aws_eip.main[0].public_ip : null
}

output "root_volume_id" {
  description = "ID of the root EBS volume"
  value       = aws_instance.main.root_block_device[0].volume_id
}

output "dns_record" {
  description = "DNS record FQDN (if created)"
  value       = var.create_dns_record && var.route53_zone_id != null ? aws_route53_record.main[0].fqdn : null
}

output "private_dns_record" {
  description = "Private DNS record FQDN (if created)"
  value       = var.create_private_dns_record && var.private_zone_id != null ? aws_route53_record.private[0].fqdn : null
}

output "instance_state" {
  description = "State of the instance"
  value       = aws_instance.main.instance_state
}

output "ami_id" {
  description = "AMI ID used for the instance"
  value       = aws_instance.main.ami
}
