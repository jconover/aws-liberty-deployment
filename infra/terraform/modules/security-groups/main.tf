# Security Groups Module for AWS Liberty Deployment Platform
# Defines security groups for all platform components

locals {
  common_tags = merge(var.tags, {
    Module    = "security-groups"
    ManagedBy = "terraform"
  })
}

# Bastion/Jump Host Security Group
resource "aws_security_group" "bastion" {
  name        = "${var.project_name}-${var.environment}-bastion-sg"
  description = "Security group for bastion host"
  vpc_id      = var.vpc_id

  # SSH from allowed CIDRs only
  ingress {
    description = "SSH from allowed CIDRs"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidrs
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-bastion-sg"
    Role = "bastion"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# AWX/Ansible Automation Server Security Group
resource "aws_security_group" "awx" {
  name        = "${var.project_name}-${var.environment}-awx-sg"
  description = "Security group for AWX automation server"
  vpc_id      = var.vpc_id

  # SSH from bastion
  ingress {
    description     = "SSH from bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  # AWX Web UI (HTTPS)
  ingress {
    description = "AWX Web UI from allowed CIDRs"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.allowed_web_cidrs
  }

  # AWX Web UI (HTTP - redirect to HTTPS)
  ingress {
    description = "AWX Web UI HTTP redirect"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.allowed_web_cidrs
  }

  # AWX API (internal access)
  ingress {
    description = "AWX API from VPC"
    from_port   = 8052
    to_port     = 8052
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Node exporter for Prometheus
  ingress {
    description     = "Node exporter from monitoring"
    from_port       = 9100
    to_port         = 9100
    protocol        = "tcp"
    security_groups = [aws_security_group.monitoring.id]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-awx-sg"
    Role = "awx"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Monitoring Stack Security Group (Prometheus/Grafana)
resource "aws_security_group" "monitoring" {
  name        = "${var.project_name}-${var.environment}-monitoring-sg"
  description = "Security group for monitoring stack (Prometheus/Grafana)"
  vpc_id      = var.vpc_id

  # SSH from bastion
  ingress {
    description     = "SSH from bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  # Grafana UI (HTTPS)
  ingress {
    description = "Grafana UI from allowed CIDRs"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.allowed_web_cidrs
  }

  # Grafana UI (HTTP - for internal access)
  ingress {
    description = "Grafana UI HTTP"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = var.allowed_web_cidrs
  }

  # Prometheus UI (internal only)
  ingress {
    description = "Prometheus UI from VPC"
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Alertmanager (internal only)
  ingress {
    description = "Alertmanager from VPC"
    from_port   = 9093
    to_port     = 9093
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Node exporter (self-monitoring)
  ingress {
    description = "Node exporter self"
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    self        = true
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-monitoring-sg"
    Role = "monitoring"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Liberty Application Server Security Group
resource "aws_security_group" "liberty" {
  name        = "${var.project_name}-${var.environment}-liberty-sg"
  description = "Security group for Liberty application servers"
  vpc_id      = var.vpc_id

  # SSH from bastion and AWX
  ingress {
    description     = "SSH from bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  ingress {
    description     = "SSH from AWX for automation"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.awx.id]
  }

  # Liberty HTTP port
  ingress {
    description = "Liberty HTTP from ALB"
    from_port   = 9080
    to_port     = 9080
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Liberty HTTPS port
  ingress {
    description = "Liberty HTTPS from ALB"
    from_port   = 9443
    to_port     = 9443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Liberty Admin port (internal only)
  ingress {
    description     = "Liberty Admin from bastion"
    from_port       = 9043
    to_port         = 9043
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  # Node exporter for Prometheus
  ingress {
    description     = "Node exporter from monitoring"
    from_port       = 9100
    to_port         = 9100
    protocol        = "tcp"
    security_groups = [aws_security_group.monitoring.id]
  }

  # Liberty metrics exporter
  ingress {
    description     = "Liberty metrics from monitoring"
    from_port       = 9545
    to_port         = 9545
    protocol        = "tcp"
    security_groups = [aws_security_group.monitoring.id]
  }

  # JMX for monitoring (optional)
  ingress {
    description     = "JMX from monitoring"
    from_port       = 9999
    to_port         = 9999
    protocol        = "tcp"
    security_groups = [aws_security_group.monitoring.id]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-liberty-sg"
    Role = "liberty"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Application Load Balancer Security Group
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-${var.environment}-alb-sg"
  description = "Security group for Application Load Balancer"
  vpc_id      = var.vpc_id

  # HTTPS from anywhere (or restricted CIDRs)
  ingress {
    description = "HTTPS from allowed CIDRs"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.alb_allowed_cidrs
  }

  # HTTP redirect
  ingress {
    description = "HTTP redirect"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.alb_allowed_cidrs
  }

  egress {
    description = "Allow all outbound to VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-alb-sg"
    Role = "alb"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Internal communication security group rule
# Allow Liberty servers to communicate with each other for clustering
resource "aws_security_group_rule" "liberty_cluster" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "tcp"
  security_group_id        = aws_security_group.liberty.id
  source_security_group_id = aws_security_group.liberty.id
  description              = "Liberty cluster internal communication"
}
