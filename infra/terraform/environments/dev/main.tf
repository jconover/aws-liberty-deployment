# Development Environment - Main Configuration
# AWS Liberty Deployment Platform
# Simplified setup with cost optimizations for development

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "liberty-platform-terraform-state"
    key            = "dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "liberty-platform-terraform-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

locals {
  environment = "dev"

  common_tags = {
    Project     = var.project_name
    Environment = local.environment
    ManagedBy   = "terraform"
    Owner       = var.owner
  }
}

# VPC Module - Simplified for dev
module "vpc" {
  source = "../../modules/vpc"

  project_name       = var.project_name
  environment        = local.environment
  vpc_cidr           = var.vpc_cidr
  az_count           = 2
  enable_nat_gateway = true
  single_nat_gateway = true  # Cost savings for dev
  enable_flow_logs   = false # Optional for dev
  enable_vpc_endpoints = false # Cost savings

  tags = local.common_tags
}

# IAM Module
module "iam" {
  source = "../../modules/iam"

  project_name                = var.project_name
  environment                 = local.environment
  create_github_oidc_provider = false

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
  create_eip           = false  # Use dynamic IP for dev
  key_name             = var.ssh_key_name
  iam_instance_profile = module.iam.bastion_instance_profile_name
  kms_key_id           = module.iam.kms_key_arn

  root_volume_size = 20

  enable_termination_protection = false
  create_cloudwatch_alarms     = false

  tags = local.common_tags
}

# AWX Automation Server (combined with monitoring for dev)
module "awx" {
  source = "../../modules/ec2-instance"

  name                 = "${var.project_name}-${local.environment}-awx"
  environment          = local.environment
  role                 = "awx"
  instance_type        = "t3.medium"  # Smaller for dev
  subnet_id            = module.vpc.private_subnet_ids[0]
  security_group_ids   = [
    module.security_groups.awx_security_group_id,
    module.security_groups.monitoring_security_group_id  # Combined for dev
  ]
  associate_public_ip  = false
  key_name             = var.ssh_key_name
  iam_instance_profile = module.iam.awx_instance_profile_name
  kms_key_id           = module.iam.kms_key_arn

  root_volume_size = 50

  additional_volumes = [
    {
      device_name = "/dev/sdf"
      volume_size = 50  # Smaller for dev
      volume_type = "gp3"
    }
  ]

  additional_user_data = <<-EOF
    # Install Docker for AWX and monitoring
    yum install -y docker
    systemctl enable docker
    systemctl start docker

    # Install Docker Compose
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose

    # Install Python and pip
    yum install -y python3 python3-pip
    pip3 install docker-compose ansible

    # Mount data volume
    mkfs -t xfs /dev/sdf
    mkdir -p /var/lib/awx
    echo '/dev/sdf /var/lib/awx xfs defaults 0 0' >> /etc/fstab
    mount -a
  EOF

  enable_termination_protection = false
  create_cloudwatch_alarms     = false

  tags = local.common_tags
}

# Single Liberty Server for Development
module "liberty" {
  source = "../../modules/ec2-instance"

  name                 = "${var.project_name}-${local.environment}-liberty"
  environment          = local.environment
  role                 = "liberty"
  instance_type        = "t3.small"  # Smaller for dev
  subnet_id            = module.vpc.private_subnet_ids[0]
  security_group_ids   = [module.security_groups.liberty_security_group_id]
  associate_public_ip  = false
  key_name             = var.ssh_key_name
  iam_instance_profile = module.iam.liberty_instance_profile_name
  kms_key_id           = module.iam.kms_key_arn

  root_volume_size = 30

  additional_volumes = [
    {
      device_name = "/dev/sdf"
      volume_size = 50  # Smaller for dev
      volume_type = "gp3"
    }
  ]

  additional_user_data = <<-EOF
    # Install Java for Liberty
    yum install -y java-17-amazon-corretto java-17-amazon-corretto-devel

    # Create liberty user
    useradd -r -s /bin/bash liberty

    # Mount data volume
    mkfs -t xfs /dev/sdf
    mkdir -p /opt/liberty
    echo '/dev/sdf /opt/liberty xfs defaults 0 0' >> /etc/fstab
    mount -a
    chown -R liberty:liberty /opt/liberty

    # Install node_exporter
    cd /tmp
    curl -LO https://github.com/prometheus/node_exporter/releases/download/v1.7.0/node_exporter-1.7.0.linux-amd64.tar.gz
    tar xzf node_exporter-1.7.0.linux-amd64.tar.gz
    cp node_exporter-1.7.0.linux-amd64/node_exporter /usr/local/bin/

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

  enable_termination_protection = false
  create_cloudwatch_alarms     = false

  tags = local.common_tags
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

resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
