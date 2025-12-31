# Production Environment - Main Configuration
# AWS Liberty Deployment Platform

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket       = "liberty-platform-terraform-state"
    key          = "prod/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

locals {
  environment = "prod"

  common_tags = {
    Project     = var.project_name
    Environment = local.environment
    ManagedBy   = "terraform"
    Owner       = var.owner
  }
}

# VPC Module
module "vpc" {
  source = "../../modules/vpc"

  project_name       = var.project_name
  environment        = local.environment
  vpc_cidr           = var.vpc_cidr
  az_count           = var.az_count
  enable_nat_gateway = true
  single_nat_gateway = false # HA for production
  enable_flow_logs   = true
  enable_vpc_endpoints = true

  tags = local.common_tags
}

# IAM Module
module "iam" {
  source = "../../modules/iam"

  project_name                = var.project_name
  environment                 = local.environment
  create_github_oidc_provider = var.create_github_oidc_provider
  github_org                  = var.github_org
  github_repo                 = var.github_repo

  tags = local.common_tags
}

# Security Groups Module
module "security_groups" {
  source = "../../modules/security-groups"

  project_name      = var.project_name
  environment       = local.environment
  vpc_id            = module.vpc.vpc_id
  vpc_cidr          = module.vpc.vpc_cidr
  allowed_ssh_cidrs = var.allowed_ssh_cidrs
  allowed_web_cidrs = var.allowed_web_cidrs
  alb_allowed_cidrs = var.alb_allowed_cidrs

  tags = local.common_tags
}

# Bastion Host
module "bastion" {
  source = "../../modules/ec2-instance"

  name                 = "${var.project_name}-${local.environment}-bastion"
  environment          = local.environment
  role                 = "bastion"
  instance_type        = "t3.micro"
  subnet_id            = module.vpc.public_subnet_ids[0]
  security_group_ids   = [module.security_groups.bastion_security_group_id]
  associate_public_ip  = true
  create_eip           = true
  key_name             = var.ssh_key_name
  iam_instance_profile = module.iam.bastion_instance_profile_name
  kms_key_id           = module.iam.kms_key_arn

  root_volume_size = 20

  enable_termination_protection = true
  create_cloudwatch_alarms     = true

  tags = local.common_tags
}

# AWX Automation Server
module "awx" {
  source = "../../modules/ec2-instance"

  name                 = "${var.project_name}-${local.environment}-awx"
  environment          = local.environment
  role                 = "awx"
  instance_type        = var.awx_instance_type
  subnet_id            = module.vpc.private_subnet_ids[0]
  security_group_ids   = [module.security_groups.awx_security_group_id]
  associate_public_ip  = false
  key_name             = var.ssh_key_name
  iam_instance_profile = module.iam.awx_instance_profile_name
  kms_key_id           = module.iam.kms_key_arn

  root_volume_size = 50

  additional_volumes = [
    {
      device_name = "/dev/sdf"
      volume_size = 100
      volume_type = "gp3"
    }
  ]

  additional_user_data = <<-EOF
    # Install Docker for AWX
    yum install -y docker
    systemctl enable docker
    systemctl start docker

    # Install Docker Compose
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose

    # Install Python and pip for AWX
    yum install -y python3 python3-pip
    pip3 install docker-compose ansible

    # Mount data volume
    mkfs -t xfs /dev/sdf
    mkdir -p /var/lib/awx
    echo '/dev/sdf /var/lib/awx xfs defaults 0 0' >> /etc/fstab
    mount -a
  EOF

  enable_termination_protection = true
  create_cloudwatch_alarms     = true

  tags = local.common_tags
}

# Monitoring Server (Prometheus/Grafana)
module "monitoring" {
  source = "../../modules/ec2-instance"

  name                 = "${var.project_name}-${local.environment}-monitoring"
  environment          = local.environment
  role                 = "monitoring"
  instance_type        = var.monitoring_instance_type
  subnet_id            = module.vpc.private_subnet_ids[0]
  security_group_ids   = [module.security_groups.monitoring_security_group_id]
  associate_public_ip  = false
  key_name             = var.ssh_key_name
  iam_instance_profile = module.iam.monitoring_instance_profile_name
  kms_key_id           = module.iam.kms_key_arn

  root_volume_size = 50

  additional_volumes = [
    {
      device_name = "/dev/sdf"
      volume_size = 200  # Prometheus TSDB storage
      volume_type = "gp3"
    }
  ]

  additional_user_data = <<-EOF
    # Install Docker for monitoring stack
    yum install -y docker
    systemctl enable docker
    systemctl start docker

    # Install Docker Compose
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose

    # Mount data volume for Prometheus
    mkfs -t xfs /dev/sdf
    mkdir -p /var/lib/prometheus
    echo '/dev/sdf /var/lib/prometheus xfs defaults 0 0' >> /etc/fstab
    mount -a
    chown -R 65534:65534 /var/lib/prometheus  # nobody user for Prometheus
  EOF

  enable_termination_protection = true
  create_cloudwatch_alarms     = true

  tags = local.common_tags
}

# Liberty Application Servers
module "liberty" {
  source   = "../../modules/ec2-instance"
  for_each = { for idx in range(var.liberty_instance_count) : idx => idx }

  name                 = "${var.project_name}-${local.environment}-liberty-${each.key + 1}"
  environment          = local.environment
  role                 = "liberty"
  instance_type        = var.liberty_instance_type
  subnet_id            = module.vpc.private_subnet_ids[each.key % length(module.vpc.private_subnet_ids)]
  security_group_ids   = [module.security_groups.liberty_security_group_id]
  associate_public_ip  = false
  key_name             = var.ssh_key_name
  iam_instance_profile = module.iam.liberty_instance_profile_name
  kms_key_id           = module.iam.kms_key_arn

  root_volume_size = 50

  additional_volumes = [
    {
      device_name = "/dev/sdf"
      volume_size = var.liberty_data_volume_size
      volume_type = "gp3"
    }
  ]

  additional_user_data = <<-EOF
    # Install Java for Liberty
    yum install -y java-17-amazon-corretto java-17-amazon-corretto-devel

    # Create liberty user
    useradd -r -s /bin/bash liberty

    # Mount data volume for Liberty
    mkfs -t xfs /dev/sdf
    mkdir -p /opt/liberty
    echo '/dev/sdf /opt/liberty xfs defaults 0 0' >> /etc/fstab
    mount -a
    chown -R liberty:liberty /opt/liberty

    # Install node_exporter for Prometheus monitoring
    cd /tmp
    curl -LO https://github.com/prometheus/node_exporter/releases/download/v1.7.0/node_exporter-1.7.0.linux-amd64.tar.gz
    tar xzf node_exporter-1.7.0.linux-amd64.tar.gz
    cp node_exporter-1.7.0.linux-amd64/node_exporter /usr/local/bin/

    # Create systemd service for node_exporter
    cat > /etc/systemd/system/node_exporter.service << 'NODEEOF'
    [Unit]
    Description=Node Exporter
    After=network.target

    [Service]
    User=nobody
    ExecStart=/usr/local/bin/node_exporter
    Restart=always

    [Install]
    WantedBy=multi-user.target
    NODEEOF

    systemctl daemon-reload
    systemctl enable node_exporter
    systemctl start node_exporter
  EOF

  enable_termination_protection = false  # Allow scaling
  create_cloudwatch_alarms     = true

  tags = merge(local.common_tags, {
    LibertyIndex = each.key + 1
  })
}

# SNS Topic for Alerts
resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-${local.environment}-alerts"

  tags = local.common_tags
}

resource "aws_sns_topic_subscription" "alerts_email" {
  count     = var.alert_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# S3 Bucket for Application Artifacts
resource "aws_s3_bucket" "artifacts" {
  bucket = "${var.project_name}-${local.environment}-artifacts"

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${local.environment}-artifacts"
  })
}

resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = module.iam.kms_key_arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
