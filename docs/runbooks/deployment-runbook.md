# Liberty Platform Deployment Runbook

## Table of Contents
1. [Initial Infrastructure Deployment](#initial-infrastructure-deployment)
2. [AWX Setup](#awx-setup)
3. [Liberty Server Deployment](#liberty-server-deployment)
4. [Application Deployment](#application-deployment)
5. [Monitoring Setup](#monitoring-setup)
6. [Common Operations](#common-operations)
7. [Troubleshooting](#troubleshooting)

---

## Initial Infrastructure Deployment

### Prerequisites
- AWS CLI configured with appropriate credentials
- Terraform >= 1.5.0 installed
- SSH key pair created in AWS
- Access to the repository

### Step 1: Bootstrap Terraform Backend

```bash
cd infra/terraform/backend

# Initialize and apply
terraform init
terraform plan
terraform apply

# Note the outputs for state bucket and lock table
```

### Step 2: Create SSH Key Pair

```bash
# Generate SSH key
ssh-keygen -t rsa -b 4096 -f ~/.ssh/liberty-platform-prod -N ""

# Import to AWS
aws ec2 import-key-pair \
  --key-name liberty-platform-prod \
  --public-key-material fileb://~/.ssh/liberty-platform-prod.pub \
  --region us-east-1
```

### Step 3: Configure Environment Variables

```bash
cd infra/terraform/environments/prod

# Copy example and edit
cp terraform.tfvars.example terraform.tfvars

# Edit with your values
vim terraform.tfvars
```

Required configurations:
- `allowed_ssh_cidrs`: Your office/VPN IP ranges
- `allowed_web_cidrs`: IPs allowed to access AWX/Grafana
- `ssh_key_name`: Name of SSH key pair
- `alert_email`: Email for alerts

### Step 4: Deploy Infrastructure

```bash
# Initialize
terraform init

# Plan and review
terraform plan -out=tfplan

# Apply
terraform apply tfplan

# Save outputs
terraform output > ../../outputs-prod.txt
```

### Step 5: Verify Deployment

```bash
# Get bastion IP
BASTION_IP=$(terraform output -raw bastion_public_ip)

# Test SSH connectivity
ssh -i ~/.ssh/liberty-platform-prod.pem ec2-user@$BASTION_IP
```

---

## AWX Setup

### Step 1: Connect to AWX Server

```bash
# Get IPs from Terraform output
BASTION_IP=$(terraform output -raw bastion_public_ip)
AWX_IP=$(terraform output -raw awx_private_ip)

# SSH to AWX via bastion
ssh -i ~/.ssh/liberty-platform-prod.pem \
    -J ec2-user@$BASTION_IP \
    ec2-user@$AWX_IP
```

### Step 2: Run AWX Playbook

```bash
# From your local machine
cd ansible

# Update inventory with actual IPs
vim inventory/hosts.yml

# Run AWX deployment
ansible-playbook playbooks/deploy-awx.yml \
  -i inventory/hosts.yml \
  -l awx \
  --private-key ~/.ssh/liberty-platform-prod.pem
```

### Step 3: Access AWX UI

```bash
# Set up SSH tunnel
ssh -i ~/.ssh/liberty-platform-prod.pem \
    -L 8052:$AWX_IP:8052 \
    ec2-user@$BASTION_IP

# Access in browser: http://localhost:8052
# Default credentials: admin / (from vault)
```

### Step 4: Configure AWX

1. **Add Credentials**:
   - SSH Private Key for Liberty servers
   - AWS credentials for dynamic inventory

2. **Add Inventory**:
   - Create AWS EC2 dynamic inventory
   - Configure with your region and tags

3. **Add Project**:
   - SCM Type: Git
   - URL: Your repository URL
   - Branch: main

4. **Create Job Templates**:
   - Import from `platform/awx/job-templates.yml`

---

## Liberty Server Deployment

### Step 1: Verify Connectivity

```bash
# From AWX or bastion
ansible liberty -m ping -i inventory/aws_ec2.yml
```

### Step 2: Deploy Liberty Servers

```bash
# Using AWX UI:
# 1. Navigate to Templates
# 2. Launch "Deploy New Liberty Server"
# 3. Select target hosts

# Or via CLI:
ansible-playbook playbooks/deploy-liberty.yml \
  -i inventory/aws_ec2.yml \
  -l liberty \
  --private-key ~/.ssh/liberty-platform-prod.pem
```

### Step 3: Verify Liberty Installation

```bash
# SSH to Liberty server
ssh -J ec2-user@$BASTION_IP ec2-user@<liberty-ip>

# Check service status
sudo systemctl status liberty

# Check logs
sudo tail -f /var/log/liberty/messages.log

# Test health endpoint
curl http://localhost:9080/health
```

---

## Application Deployment

### Step 1: Upload Artifact to S3

```bash
# Build your application
mvn clean package

# Upload to S3
aws s3 cp target/myapp.war \
  s3://liberty-platform-prod-artifacts/myapp/1.0.0/myapp.war
```

### Step 2: Deploy via AWX

1. Navigate to **Templates** > **Deploy Application**
2. Click **Launch**
3. Fill in survey:
   - Application Name: `myapp`
   - Version: `1.0.0`
   - Artifact Source: `s3`
   - Artifact URL: `s3://liberty-platform-prod-artifacts/myapp/1.0.0`

### Step 3: Verify Deployment

```bash
# Check application health
curl http://<liberty-ip>:9080/myapp/health

# Check logs
ssh -J ec2-user@$BASTION_IP ec2-user@<liberty-ip>
sudo tail -f /opt/liberty/wlp/usr/servers/defaultServer/logs/messages.log
```

### Rolling Update Procedure

For zero-downtime updates:

1. Launch **Rolling Update** job template
2. Fill in survey with new version
3. Monitor progress in AWX
4. Verify each server before proceeding

---

## Monitoring Setup

### Step 1: Deploy Monitoring Stack

```bash
ansible-playbook playbooks/deploy-monitoring.yml \
  -i inventory/aws_ec2.yml \
  -l monitoring \
  --private-key ~/.ssh/liberty-platform-prod.pem
```

### Step 2: Access Grafana

```bash
# SSH tunnel
ssh -i ~/.ssh/liberty-platform-prod.pem \
    -L 3000:$MONITORING_IP:3000 \
    ec2-user@$BASTION_IP

# Browser: http://localhost:3000
# Credentials: admin / (from vault)
```

### Step 3: Verify Prometheus Targets

1. Access Prometheus: `http://localhost:9090` (via tunnel)
2. Navigate to Status > Targets
3. Verify all targets are UP

### Step 4: Configure Alerts

1. Edit `/etc/alertmanager/alertmanager.yml` on monitoring server
2. Configure email/Slack receivers
3. Restart Alertmanager: `sudo systemctl restart monitoring`

---

## Common Operations

### Scale Liberty Servers

```bash
# Edit Terraform variables
cd infra/terraform/environments/prod
vim terraform.tfvars

# Change liberty_instance_count
liberty_instance_count = 4

# Apply
terraform plan -out=tfplan
terraform apply tfplan

# Configure new servers
ansible-playbook playbooks/deploy-liberty.yml \
  -i inventory/aws_ec2.yml \
  -l liberty
```

### Update Liberty Configuration

```bash
# Edit group_vars
vim ansible/group_vars/liberty.yml

# Apply configuration
ansible-playbook playbooks/deploy-liberty.yml \
  -i inventory/aws_ec2.yml \
  -l liberty \
  --tags liberty-config
```

### Rotate Credentials

```bash
# Update in AWS Secrets Manager
aws secretsmanager update-secret \
  --secret-id liberty-platform/prod/db-password \
  --secret-string "new-password"

# Redeploy affected servers
ansible-playbook playbooks/deploy-liberty.yml \
  -i inventory/aws_ec2.yml \
  -l liberty
```

---

## Troubleshooting

### Liberty Server Won't Start

```bash
# Check service status
sudo systemctl status liberty

# Check logs
sudo journalctl -u liberty -n 100

# Check Liberty logs
sudo tail -f /opt/liberty/wlp/usr/servers/defaultServer/logs/messages.log

# Verify Java
java -version

# Manual start for debugging
sudo -u liberty /opt/liberty/wlp/bin/server run defaultServer
```

### AWX Job Fails

1. Check job output in AWX UI
2. Verify inventory is refreshed
3. Check SSH connectivity:
   ```bash
   ansible <host> -m ping -vvv
   ```
4. Verify credentials are correct
5. Check AWX logs:
   ```bash
   sudo docker logs awx_task
   ```

### Prometheus Not Scraping Targets

```bash
# Check target status in Prometheus UI

# Verify node_exporter is running
sudo systemctl status node_exporter

# Check firewall rules
sudo ss -tlnp | grep 9100

# Test connectivity from monitoring server
curl http://<target-ip>:9100/metrics
```

### Application Deployment Rollback

```bash
# Using AWX workflow with rollback

# Or manual:
ansible-playbook playbooks/deploy-app.yml \
  -i inventory/aws_ec2.yml \
  -l liberty \
  -e "app_name=myapp app_version=1.0.0-previous artifact_source=s3"
```

### Infrastructure Issues

```bash
# Check Terraform state
terraform state list

# Refresh state
terraform refresh

# View resource details
terraform state show module.liberty[\"0\"]

# Force recreation if needed
terraform taint module.liberty[\"0\"].aws_instance.main
terraform apply
```

---

## Emergency Procedures

### Complete Infrastructure Rebuild

```bash
# Destroy (CAUTION - data loss!)
terraform destroy

# Recreate
terraform apply

# Redeploy all components
ansible-playbook playbooks/site.yml -i inventory/aws_ec2.yml
```

### Restore from Backup

1. Restore Terraform state from S3 versioned backup
2. Run `terraform apply` to reconcile
3. Restore AWX database if needed
4. Redeploy applications from S3 artifacts

### Contact Information

| Role | Contact |
|------|---------|
| Platform Team | platform-team@example.com |
| On-Call | +1-555-0100 |
| AWS Support | via AWS Console |
