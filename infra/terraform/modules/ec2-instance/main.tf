# EC2 Instance Module for AWS Liberty Deployment Platform
# Flexible module for creating EC2 instances with various configurations

locals {
  common_tags = merge(var.tags, {
    Module    = "ec2-instance"
    ManagedBy = "terraform"
  })

  # User data script with cloud-init
  default_user_data = <<-EOF
    #!/bin/bash
    set -e

    # Update system packages
    yum update -y

    # Install SSM agent (if not already installed)
    yum install -y amazon-ssm-agent
    systemctl enable amazon-ssm-agent
    systemctl start amazon-ssm-agent

    # Install CloudWatch agent
    yum install -y amazon-cloudwatch-agent

    # Install common utilities
    yum install -y git curl wget unzip jq

    # Set hostname
    hostnamectl set-hostname ${var.name}

    # Configure timezone
    timedatectl set-timezone UTC

    # Enable and start chronyd for time sync
    systemctl enable chronyd
    systemctl start chronyd

    ${var.additional_user_data}
  EOF
}

# Get the latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux_2023" {
  count       = var.ami_id == null ? 1 : 0
  most_recent = true
  owners      = var.ami_owners

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

# Get the latest Amazon Linux 2 AMI (alternative)
data "aws_ami" "amazon_linux_2" {
  count       = var.ami_id == null && var.use_amazon_linux_2 ? 1 : 0
  most_recent = true
  owners      = var.ami_owners

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# EC2 Instance
resource "aws_instance" "main" {
  ami           = var.ami_id != null ? var.ami_id : (var.use_amazon_linux_2 ? data.aws_ami.amazon_linux_2[0].id : data.aws_ami.amazon_linux_2023[0].id)
  instance_type = var.instance_type

  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = var.security_group_ids
  associate_public_ip_address = var.associate_public_ip
  key_name                    = var.key_name

  iam_instance_profile = var.iam_instance_profile

  # Root volume
  root_block_device {
    volume_type           = var.root_volume_type
    volume_size           = var.root_volume_size
    encrypted             = true
    kms_key_id            = var.kms_key_id
    delete_on_termination = var.delete_root_volume_on_termination
    # Tags applied via volume_tags below
  }

  # Additional EBS volumes
  dynamic "ebs_block_device" {
    for_each = var.additional_volumes
    content {
      device_name           = ebs_block_device.value.device_name
      volume_type           = lookup(ebs_block_device.value, "volume_type", "gp3")
      volume_size           = ebs_block_device.value.volume_size
      encrypted             = true
      kms_key_id            = var.kms_key_id
      delete_on_termination = lookup(ebs_block_device.value, "delete_on_termination", true)
      # Tags applied via volume_tags below
    }
  }

  user_data                   = base64encode(var.custom_user_data != null ? var.custom_user_data : local.default_user_data)
  user_data_replace_on_change = var.user_data_replace_on_change

  # Enable detailed monitoring for production
  monitoring = var.enable_detailed_monitoring

  # Disable termination protection for non-prod (can be overridden)
  disable_api_termination = var.enable_termination_protection

  # Enable stop protection
  disable_api_stop = var.enable_stop_protection

  # Instance metadata options (IMDSv2 required for security)
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # IMDSv2 required
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  # Credit specification for burstable instances
  dynamic "credit_specification" {
    for_each = can(regex("^t[23]\\.", var.instance_type)) ? [1] : []
    content {
      cpu_credits = var.cpu_credits
    }
  }

  tags = merge(local.common_tags, {
    Name        = var.name
    Role        = var.role
    Environment = var.environment
  })

  volume_tags = merge(local.common_tags, {
    Name = "${var.name}-volumes"
  })
}

# Elastic IP (optional)
resource "aws_eip" "main" {
  count = var.create_eip ? 1 : 0

  domain   = "vpc"
  instance = aws_instance.main.id

  tags = merge(local.common_tags, {
    Name = "${var.name}-eip"
  })
}

# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  count = var.create_cloudwatch_alarms ? 1 : 0

  alarm_name          = "${var.name}-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = var.cpu_alarm_threshold
  alarm_description   = "This metric monitors EC2 CPU utilization"

  dimensions = {
    InstanceId = aws_instance.main.id
  }

  alarm_actions = var.alarm_actions
  ok_actions    = var.alarm_actions

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "status_check" {
  count = var.create_cloudwatch_alarms ? 1 : 0

  alarm_name          = "${var.name}-status-check"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Maximum"
  threshold           = 0
  alarm_description   = "This metric monitors EC2 status checks"

  dimensions = {
    InstanceId = aws_instance.main.id
  }

  alarm_actions = var.alarm_actions

  tags = local.common_tags
}

# Route53 record (optional)
resource "aws_route53_record" "main" {
  count = var.create_dns_record && var.route53_zone_id != null ? 1 : 0

  zone_id = var.route53_zone_id
  name    = var.dns_name != null ? var.dns_name : var.name
  type    = "A"
  ttl     = var.dns_ttl

  records = [var.create_eip ? aws_eip.main[0].public_ip : (var.associate_public_ip ? aws_instance.main.public_ip : aws_instance.main.private_ip)]
}

# Private DNS record (optional)
resource "aws_route53_record" "private" {
  count = var.create_private_dns_record && var.private_zone_id != null ? 1 : 0

  zone_id = var.private_zone_id
  name    = var.dns_name != null ? var.dns_name : var.name
  type    = "A"
  ttl     = var.dns_ttl

  records = [aws_instance.main.private_ip]
}
