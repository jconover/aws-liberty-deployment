# Operational Procedures

## Daily Operations

### Health Check Procedure

1. **Verify Infrastructure Status**
   ```bash
   # Check all EC2 instances
   aws ec2 describe-instances \
     --filters "Name=tag:Project,Values=liberty-platform" \
     --query "Reservations[*].Instances[*].[InstanceId,State.Name,Tags[?Key=='Name'].Value|[0]]" \
     --output table
   ```

2. **Check Monitoring Stack**
   - Access Grafana dashboard
   - Review "Liberty Server Overview" dashboard
   - Check for any firing alerts in Alertmanager

3. **Verify AWX Status**
   - Login to AWX UI
   - Check job history for failures
   - Verify inventory sync is current

### Log Review

```bash
# Liberty application logs
ssh -J bastion liberty-server
sudo tail -f /opt/liberty/wlp/usr/servers/defaultServer/logs/messages.log

# System logs
sudo journalctl -u liberty --since "1 hour ago"

# AWX logs
sudo docker logs awx_task --since 1h
```

---

## Weekly Operations

### Capacity Review

1. Check disk usage on all servers:
   ```bash
   ansible liberty -m shell -a "df -h"
   ```

2. Review memory and CPU trends in Grafana

3. Check S3 artifact bucket size:
   ```bash
   aws s3 ls s3://liberty-platform-prod-artifacts --summarize --recursive
   ```

### Security Updates

```bash
# Check for available updates
ansible all -m yum -a "list=updates"

# Apply security updates (non-production first)
ansible liberty -m yum -a "name=* state=latest security=yes" --check

# If approved, apply
ansible liberty -m yum -a "name=* state=latest security=yes"
```

### Backup Verification

1. Verify Terraform state bucket versioning:
   ```bash
   aws s3api list-object-versions \
     --bucket liberty-platform-terraform-state \
     --prefix prod/ \
     --max-keys 5
   ```

2. Test AWX database backup:
   ```bash
   # On AWX server
   sudo docker exec awx_postgres pg_dump -U awx awx > /tmp/awx_backup_test.sql
   ```

---

## Incident Response

### Severity Levels

| Level | Description | Response Time | Examples |
|-------|-------------|---------------|----------|
| P1 | Production down | 15 minutes | All Liberty servers down |
| P2 | Degraded service | 1 hour | 50%+ servers affected |
| P3 | Minor impact | 4 hours | Single server issue |
| P4 | No impact | Next business day | Non-critical alerts |

### P1 Incident Procedure

1. **Acknowledge alert** in Alertmanager/PagerDuty

2. **Initial assessment** (5 min):
   ```bash
   # Check AWS service health
   aws health describe-events --region us-east-1

   # Check EC2 status
   aws ec2 describe-instance-status \
     --filters "Name=tag:Project,Values=liberty-platform"
   ```

3. **Identify scope**:
   - Which services are affected?
   - When did it start?
   - Any recent changes?

4. **Engage stakeholders**:
   - Notify on-call team
   - Update status page
   - Start incident channel

5. **Remediation**:
   - Follow runbook for specific failure
   - If unknown, escalate to senior engineer

6. **Resolution**:
   - Verify all services restored
   - Document timeline
   - Schedule post-mortem

### Common Incident Scenarios

#### All Liberty Servers Unreachable

```bash
# Check VPC/networking
aws ec2 describe-vpc-endpoints --filters "Name=vpc-id,Values=vpc-xxx"

# Check NAT Gateway
aws ec2 describe-nat-gateways --filter "Name=state,Values=available"

# Check security groups
aws ec2 describe-security-groups --group-ids sg-xxx

# If networking issue, check route tables
aws ec2 describe-route-tables --filters "Name=vpc-id,Values=vpc-xxx"
```

#### AWX Not Responding

```bash
# SSH to AWX server
ssh -J bastion awx-server

# Check Docker containers
sudo docker ps -a

# Restart AWX
sudo systemctl restart awx

# Check logs
sudo docker logs awx_web --tail 100
sudo docker logs awx_task --tail 100
```

#### High Memory on Liberty Server

```bash
# Generate heap dump
sudo -u liberty jmap -dump:format=b,file=/tmp/heap.hprof <pid>

# Restart Liberty (if critical)
sudo systemctl restart liberty

# Analyze heap dump offline
# Transfer file and use Eclipse MAT or similar
```

---

## Change Management

### Change Categories

| Category | Approval | Examples |
|----------|----------|----------|
| Standard | Pre-approved | Routine deployments, config changes |
| Normal | CAB review | New features, infrastructure changes |
| Emergency | Post-approval | Production fixes |

### Standard Change Procedure

1. Create change ticket
2. Run in dev/staging first
3. Execute during change window
4. Verify with health checks
5. Document completion

### Infrastructure Change Procedure

1. **Create PR** with Terraform changes
2. **Review** plan output in PR comments
3. **Approve** by at least 2 reviewers
4. **Merge** to main branch
5. **Apply** via GitHub Actions (dev auto, prod manual)
6. **Verify** infrastructure state

---

## Maintenance Windows

### Scheduled Maintenance

| Window | Day | Time (UTC) | Purpose |
|--------|-----|------------|---------|
| Weekly | Sunday | 02:00-04:00 | Patches, updates |
| Monthly | First Sunday | 02:00-06:00 | Major updates |

### Maintenance Procedure

1. **Pre-maintenance**:
   - Notify stakeholders 48h in advance
   - Update status page
   - Prepare rollback plan

2. **During maintenance**:
   - Follow change procedure
   - Monitor for issues
   - Keep stakeholders updated

3. **Post-maintenance**:
   - Verify all services
   - Update status page
   - Document changes

---

## Capacity Planning

### Metrics to Monitor

| Metric | Warning | Critical | Action |
|--------|---------|----------|--------|
| CPU | 70% | 85% | Scale or optimize |
| Memory | 75% | 90% | Scale or investigate leak |
| Disk | 70% | 85% | Cleanup or expand |
| Connections | 80% max | 95% max | Increase pool or scale |

### Scaling Procedure

1. **Evaluate need**:
   - Review metrics trends
   - Check upcoming demand (events, releases)

2. **Plan scaling**:
   - Horizontal (add servers) vs Vertical (larger instance)
   - Cost impact analysis

3. **Execute**:
   ```bash
   # Update Terraform
   # liberty_instance_count = N
   terraform apply

   # Configure new servers
   ansible-playbook playbooks/deploy-liberty.yml -l liberty
   ```

4. **Verify**:
   - Check new servers in monitoring
   - Update load balancer if needed

---

## Disaster Recovery

### RTO/RPO Targets

| Component | RTO | RPO |
|-----------|-----|-----|
| Infrastructure | 30 min | 0 |
| AWX | 1 hour | 24h |
| Liberty Servers | 30 min | 0 |
| Applications | 15 min | Last artifact |

### DR Procedure

1. **Assess impact**:
   - Which AZ/region affected?
   - Data loss extent?

2. **Failover decision**:
   - If single AZ: failover to other AZ
   - If region: invoke DR region

3. **Recovery steps**:
   ```bash
   # In DR region
   cd infra/terraform/environments/prod-dr
   terraform init
   terraform apply

   # Deploy applications
   ansible-playbook playbooks/site.yml -i inventory/dr_hosts.yml
   ```

4. **Failback** (when primary restored):
   - Sync any new data
   - DNS failback
   - Decommission DR resources

### DR Test Schedule

- Quarterly: Tabletop exercise
- Semi-annually: Partial failover test
- Annually: Full DR test
