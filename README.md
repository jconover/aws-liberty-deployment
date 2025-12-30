# AWS Liberty Deployment Platform

A comprehensive DevOps platform for deploying and managing IBM WebSphere Liberty application servers on AWS. This project provides automated infrastructure provisioning, configuration management, application deployment, and monitoring capabilities.

## Features

- **Infrastructure as Code**: Modular Terraform configurations for AWS resources
- **Automation**: AWX/Ansible for configuration management and deployment orchestration
- **Monitoring**: Prometheus + Grafana stack with pre-built dashboards and alerts
- **CI/CD**: GitHub Actions workflows for infrastructure and application deployments
- **Security**: Least-privilege IAM roles, encrypted storage, private networking

## Architecture

```
+------------------+     +------------------+     +------------------+
|   GitHub Actions |---->|   Terraform      |---->|   AWS            |
|   (CI/CD)        |     |   (IaC)          |     |   Infrastructure |
+------------------+     +------------------+     +------------------+
                                                          |
                                                          v
+------------------+     +------------------+     +------------------+
|   AWX            |---->|   Ansible        |---->|   Liberty        |
|   (Orchestration)|     |   (Config Mgmt)  |     |   Servers        |
+------------------+     +------------------+     +------------------+
                                                          |
                                                          v
+------------------+     +------------------+     +------------------+
|   Alertmanager   |<----|   Prometheus     |<----|   Node Exporter  |
|   (Alerts)       |     |   (Metrics)      |     |   (Collectors)   |
+------------------+     +------------------+     +------------------+
         |
         v
+------------------+
|   Grafana        |
|   (Dashboards)   |
+------------------+
```

## Prerequisites

- AWS Account with appropriate permissions
- Terraform >= 1.5.0
- Ansible >= 2.15
- AWS CLI v2
- SSH key pair in AWS

## Quick Start

### 1. Clone Repository

```bash
git clone https://github.com/jconover/aws-liberty-deployment.git
cd aws-liberty-deployment
```

### 2. Bootstrap Terraform Backend

```bash
cd infra/terraform/backend
terraform init
terraform apply
```

### 3. Configure Environment

```bash
cd ../environments/dev
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
```

### 4. Deploy Infrastructure

```bash
make tf-plan ENV=dev
make tf-apply ENV=dev
```

### 5. Deploy Platform Components

```bash
make deploy-all ENV=dev
```

## Project Structure

```
.
├── infra/terraform/           # Infrastructure as Code
│   ├── modules/               # Reusable Terraform modules
│   │   ├── vpc/               # VPC and networking
│   │   ├── security-groups/   # Security group definitions
│   │   ├── ec2-instance/      # EC2 instance module
│   │   └── iam/               # IAM roles and policies
│   ├── environments/          # Environment-specific configs
│   │   ├── dev/               # Development environment
│   │   └── prod/              # Production environment
│   └── backend/               # State backend bootstrap
│
├── ansible/                   # Configuration Management
│   ├── inventory/             # Inventory files
│   ├── roles/                 # Ansible roles
│   │   ├── common/            # Base configuration
│   │   ├── docker/            # Docker installation
│   │   ├── awx/               # AWX installation
│   │   ├── liberty/           # Liberty server setup
│   │   ├── monitoring/        # Monitoring stack
│   │   └── node_exporter/     # Prometheus exporter
│   ├── playbooks/             # Deployment playbooks
│   └── group_vars/            # Group variables
│
├── platform/                  # Platform configurations
│   ├── awx/                   # AWX job templates
│   └── monitoring/            # Monitoring configs
│
├── .github/workflows/         # CI/CD pipelines
│
├── docs/                      # Documentation
│   ├── architecture/          # Architecture docs
│   └── runbooks/              # Operational runbooks
│
├── Makefile                   # Common operations
└── README.md
```

## Components

### Infrastructure

| Component | Description |
|-----------|-------------|
| VPC | Multi-AZ VPC with public/private subnets |
| Security Groups | Least-privilege network access rules |
| EC2 Instances | Bastion, AWX, Monitoring, Liberty servers |
| IAM | Instance profiles with scoped permissions |

### AWX Job Templates

| Template | Purpose |
|----------|---------|
| Deploy New Liberty Server | Provision and configure Liberty |
| Deploy Application | Deploy app to Liberty servers |
| Rolling Update | Zero-downtime updates |
| Deploy Monitoring | Install monitoring stack |

### Monitoring

| Component | Port | Purpose |
|-----------|------|---------|
| Prometheus | 9090 | Metrics collection |
| Grafana | 3000 | Dashboards |
| Alertmanager | 9093 | Alert routing |
| Node Exporter | 9100 | System metrics |

## Common Commands

```bash
# Show all available commands
make help

# Infrastructure
make tf-plan ENV=prod          # Plan changes
make tf-apply ENV=prod         # Apply changes
make tf-output ENV=prod        # Show outputs

# Deployments
make deploy-liberty ENV=prod   # Deploy Liberty servers
make deploy-app APP_NAME=myapp APP_VERSION=1.0.0

# Access
make tunnel-awx ENV=prod       # SSH tunnel to AWX
make tunnel-grafana ENV=prod   # SSH tunnel to Grafana

# Testing
make test-connectivity ENV=prod
make lint
```

## Application Deployment

### Via AWX UI

1. Navigate to Templates
2. Launch "Deploy Application"
3. Fill in survey:
   - Application Name
   - Version
   - Artifact location

### Via Command Line

```bash
make deploy-app APP_NAME=myapp APP_VERSION=1.0.0 ENV=prod
```

### Via CI/CD

Push artifact to S3 and trigger AWX webhook.

## Monitoring

### Pre-built Dashboards

- **Liberty Server Overview**: Request rates, response times, JVM metrics
- **System Metrics**: CPU, memory, disk for all servers
- **Alert Status**: Current alerts and history

### Alert Rules

| Alert | Condition | Severity |
|-------|-----------|----------|
| InstanceDown | Target unreachable 2min | Critical |
| HighCpuUsage | CPU > 80% for 5min | Warning |
| HighMemoryUsage | Memory > 85% for 5min | Warning |
| DiskSpaceLow | Disk < 15% free | Warning |
| LibertyServerDown | Liberty down 1min | Critical |

## Security

### Network Security
- All application servers in private subnets
- Bastion host for SSH access
- Security groups with minimal permissions
- VPC Flow Logs enabled

### Encryption
- EBS volumes encrypted with KMS
- S3 buckets with SSE-KMS
- TLS for all HTTP traffic

### Authentication
- SSH key-based auth only
- AWX RBAC for job execution
- GitHub OIDC for CI/CD (no stored credentials)

## Documentation

- [Architecture Overview](docs/architecture/README.md)
- [Deployment Runbook](docs/runbooks/deployment-runbook.md)
- [Operational Procedures](docs/runbooks/operational-procedures.md)

## Contributing

1. Create feature branch
2. Make changes
3. Run `make lint`
4. Create pull request
5. Wait for CI checks
6. Get review approval

## License

MIT License - see LICENSE file for details.

## Support

- Platform Team: me
- Documentation: [docs/](docs/)
- Issues: GitHub Issues
