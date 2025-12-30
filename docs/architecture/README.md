# Liberty Platform Architecture

## Overview

The Liberty Platform is a comprehensive DevOps solution for deploying and managing IBM WebSphere Liberty application servers on AWS. It provides automated infrastructure provisioning, configuration management, application deployment, and monitoring capabilities.

## Architecture Diagram

```
                                    +-------------------+
                                    |   GitHub Actions  |
                                    |   (CI/CD)         |
                                    +--------+----------+
                                             |
                                             | OIDC Auth
                                             v
+-----------------------------------------------------------------------------------+
|                                    AWS Cloud                                       |
|                                                                                   |
|  +-------------+     +----------------------------------------------------------+ |
|  |   Route53   |     |                        VPC                               | |
|  |   (DNS)     |     |  +------------------+  +-------------------------------+ | |
|  +------+------+     |  |  Public Subnets  |  |      Private Subnets          | | |
|         |            |  |                  |  |                               | | |
|         |            |  |  +------------+  |  |  +----------+  +----------+   | | |
|         |            |  |  |  Bastion   |  |  |  |   AWX    |  |Monitoring|   | | |
|         +----------------->|   Host     +------->| Server   |  |  Stack   |   | | |
|                      |  |  +------------+  |  |  +----+-----+  +-----+----+   | | |
|                      |  |                  |  |       |              |        | | |
|                      |  |  +------------+  |  |       |   +----------+        | | |
|                      |  |  |    ALB     |  |  |       |   |                   | | |
|                      |  |  | (Optional) +------->+----+---v----+              | | |
|                      |  |  +------------+  |  |  | Liberty     |              | | |
|                      |  |                  |  |  | Server 1    |              | | |
|                      |  |  +------------+  |  |  +-------------+              | | |
|                      |  |  | NAT Gateway|  |  |                               | | |
|                      |  |  +------------+  |  |  +-------------+              | | |
|                      |  |                  |  |  | Liberty     |              | | |
|                      |  +------------------+  |  | Server 2    |              | | |
|                      |                        |  +-------------+              | | |
|                      |                        |                               | | |
|                      |                        |  +-------------+              | | |
|                      |                        |  | Liberty     |              | | |
|                      |                        |  | Server N    |              | | |
|                      |                        |  +-------------+              | | |
|                      |                        +-------------------------------+ | |
|                      +----------------------------------------------------------+ |
|                                                                                   |
|  +-------------------+  +-------------------+  +-------------------+              |
|  | S3 (Artifacts)    |  | Secrets Manager   |  | CloudWatch        |              |
|  +-------------------+  +-------------------+  +-------------------+              |
+-----------------------------------------------------------------------------------+
```

## Component Overview

### Infrastructure Layer

| Component | Purpose | Technology |
|-----------|---------|------------|
| VPC | Network isolation | AWS VPC with public/private subnets |
| Security Groups | Network access control | AWS Security Groups |
| NAT Gateway | Outbound internet for private subnets | AWS NAT Gateway |
| Bastion Host | Secure SSH access | EC2 t3.micro |

### Platform Layer

| Component | Purpose | Technology |
|-----------|---------|------------|
| AWX Server | Automation orchestration | AWX 23.x on Docker |
| Monitoring Stack | Metrics and alerting | Prometheus + Grafana + Alertmanager |

### Application Layer

| Component | Purpose | Technology |
|-----------|---------|------------|
| Liberty Servers | Application hosting | Open Liberty 24.x on EC2 |
| Node Exporters | System metrics | Prometheus Node Exporter |

### Supporting Services

| Service | Purpose |
|---------|---------|
| S3 | Artifact storage, Terraform state |
| Secrets Manager | Credential management |
| SSM Parameter Store | Configuration management |
| CloudWatch | AWS-native logging and metrics |
| KMS | Encryption key management |

## Network Architecture

### Subnet Layout

| Subnet Type | CIDR Range | Purpose |
|-------------|------------|---------|
| Public | 10.0.0.0/24, 10.0.1.0/24 | Bastion, NAT Gateway, ALB |
| Private | 10.0.128.0/24, 10.0.129.0/24 | AWX, Monitoring, Liberty |

### Security Group Rules

```
Bastion SG:
  - Inbound: SSH (22) from allowed CIDRs
  - Outbound: All

AWX SG:
  - Inbound: SSH (22) from Bastion, HTTPS (443) from allowed CIDRs
  - Inbound: Node Exporter (9100) from Monitoring
  - Outbound: All

Monitoring SG:
  - Inbound: SSH (22) from Bastion
  - Inbound: Grafana (3000), Prometheus (9090), Alertmanager (9093) from VPC
  - Outbound: All

Liberty SG:
  - Inbound: SSH (22) from Bastion and AWX
  - Inbound: HTTP (9080), HTTPS (9443) from ALB/VPC
  - Inbound: Node Exporter (9100), Metrics (9545) from Monitoring
  - Outbound: All
```

## Data Flow

### Application Deployment Flow

```
1. Developer pushes code to Git
2. CI/CD builds artifact and uploads to S3
3. AWX job template triggered (manual or webhook)
4. AWX connects to Liberty servers via SSH
5. Ansible downloads artifact from S3
6. Application deployed to Liberty
7. Health checks verify deployment
8. Monitoring confirms application health
```

### Monitoring Data Flow

```
1. Node Exporter collects system metrics
2. Liberty exposes application metrics
3. Prometheus scrapes all targets
4. Alertmanager evaluates alert rules
5. Grafana visualizes metrics
6. Alerts sent via email/Slack/webhook
```

## High Availability Considerations

### Current Design (Single AZ capable)
- Single NAT Gateway (cost-optimized)
- Multiple Liberty servers for app redundancy
- Prometheus with local storage

### Production Recommendations
- Multi-AZ deployment with NAT Gateway per AZ
- Application Load Balancer for Liberty traffic
- Prometheus with remote storage (Thanos/Cortex)
- RDS for AWX database (instead of local PostgreSQL)

## Security Architecture

### Authentication & Authorization
- SSH key-based authentication
- AWX RBAC for job execution
- AWS IAM roles for service-to-service auth
- OIDC for GitHub Actions

### Encryption
- EBS volumes encrypted with KMS
- S3 server-side encryption
- TLS for all HTTP traffic
- Secrets encrypted in Secrets Manager

### Network Security
- Private subnets for all application workloads
- Security groups with least-privilege rules
- VPC Flow Logs for audit
- No direct internet access for Liberty servers

## Disaster Recovery

### Backup Strategy
- Terraform state in versioned S3 bucket
- AWX database snapshots (if using RDS)
- Prometheus data retention (configurable)
- Application artifacts in S3 with versioning

### Recovery Procedures
1. Infrastructure: Re-run Terraform
2. AWX: Redeploy with Ansible playbook
3. Liberty: Redeploy servers and applications
4. Monitoring: Redeploy stack, historical data loss acceptable

### RTO/RPO Targets

| Component | RTO | RPO |
|-----------|-----|-----|
| Infrastructure | 30 min | 0 (IaC) |
| AWX | 1 hour | 24 hours |
| Liberty Servers | 30 min | 0 (IaC) |
| Applications | 15 min | Last artifact |
| Monitoring | 1 hour | 24 hours |
