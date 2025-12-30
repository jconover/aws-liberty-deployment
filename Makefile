# Liberty Platform Makefile
# Common operations for managing the Liberty deployment platform

.PHONY: help init plan apply destroy lint test clean

# Default environment
ENV ?= dev
AWS_REGION ?= us-east-1

# Paths
TF_DIR := infra/terraform/environments/$(ENV)
ANSIBLE_DIR := ansible
DOCS_DIR := docs

# Colors for output
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[0;33m
NC := \033[0m # No Color

help: ## Show this help message
	@echo "Liberty Platform - Available Commands"
	@echo ""
	@echo "Usage: make <target> [ENV=dev|prod]"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

# ==================== Terraform Commands ====================

tf-init: ## Initialize Terraform for environment
	@echo "$(GREEN)Initializing Terraform for $(ENV)...$(NC)"
	cd $(TF_DIR) && terraform init

tf-plan: tf-init ## Plan Terraform changes
	@echo "$(GREEN)Planning Terraform changes for $(ENV)...$(NC)"
	cd $(TF_DIR) && terraform plan -out=tfplan

tf-apply: ## Apply Terraform changes (requires tf-plan first)
	@echo "$(YELLOW)Applying Terraform changes for $(ENV)...$(NC)"
	@read -p "Are you sure you want to apply? [y/N] " confirm && [ "$$confirm" = "y" ]
	cd $(TF_DIR) && terraform apply tfplan

tf-destroy: ## Destroy Terraform infrastructure (DANGEROUS)
	@echo "$(RED)WARNING: This will destroy all infrastructure in $(ENV)!$(NC)"
	@read -p "Type 'destroy-$(ENV)' to confirm: " confirm && [ "$$confirm" = "destroy-$(ENV)" ]
	cd $(TF_DIR) && terraform destroy

tf-output: ## Show Terraform outputs
	cd $(TF_DIR) && terraform output

tf-fmt: ## Format Terraform files
	terraform fmt -recursive infra/terraform/

tf-validate: ## Validate Terraform configuration
	cd $(TF_DIR) && terraform validate

# ==================== Ansible Commands ====================

ansible-lint: ## Run Ansible linter
	@echo "$(GREEN)Running Ansible lint...$(NC)"
	cd $(ANSIBLE_DIR) && ansible-lint playbooks/ roles/

ansible-syntax: ## Check Ansible playbook syntax
	@echo "$(GREEN)Checking Ansible syntax...$(NC)"
	cd $(ANSIBLE_DIR) && ansible-playbook --syntax-check playbooks/*.yml

ansible-inventory: ## Show Ansible inventory
	cd $(ANSIBLE_DIR) && ansible-inventory --list -i inventory/aws_ec2.yml

# ==================== Deployment Commands ====================

deploy-awx: ## Deploy AWX server
	@echo "$(GREEN)Deploying AWX to $(ENV)...$(NC)"
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/deploy-awx.yml \
		-i inventory/aws_ec2.yml -l awx

deploy-monitoring: ## Deploy monitoring stack
	@echo "$(GREEN)Deploying monitoring to $(ENV)...$(NC)"
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/deploy-monitoring.yml \
		-i inventory/aws_ec2.yml -l monitoring

deploy-liberty: ## Deploy Liberty servers
	@echo "$(GREEN)Deploying Liberty servers to $(ENV)...$(NC)"
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/deploy-liberty.yml \
		-i inventory/aws_ec2.yml -l liberty

deploy-all: ## Deploy all components
	@echo "$(GREEN)Deploying all components to $(ENV)...$(NC)"
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/site.yml \
		-i inventory/aws_ec2.yml

deploy-app: ## Deploy application (requires APP_NAME and APP_VERSION)
ifndef APP_NAME
	$(error APP_NAME is required. Usage: make deploy-app APP_NAME=myapp APP_VERSION=1.0.0)
endif
ifndef APP_VERSION
	$(error APP_VERSION is required. Usage: make deploy-app APP_NAME=myapp APP_VERSION=1.0.0)
endif
	@echo "$(GREEN)Deploying $(APP_NAME) version $(APP_VERSION)...$(NC)"
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/deploy-app.yml \
		-i inventory/aws_ec2.yml -l liberty \
		-e "app_name=$(APP_NAME) app_version=$(APP_VERSION)"

rolling-update: ## Perform rolling update (requires APP_NAME and APP_VERSION)
ifndef APP_NAME
	$(error APP_NAME is required)
endif
ifndef APP_VERSION
	$(error APP_VERSION is required)
endif
	@echo "$(YELLOW)Starting rolling update of $(APP_NAME) to $(APP_VERSION)...$(NC)"
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/rolling-update.yml \
		-i inventory/aws_ec2.yml \
		-e "app_name=$(APP_NAME) app_version=$(APP_VERSION)"

# ==================== Testing Commands ====================

test-connectivity: ## Test SSH connectivity to all hosts
	@echo "$(GREEN)Testing connectivity...$(NC)"
	cd $(ANSIBLE_DIR) && ansible all -m ping -i inventory/aws_ec2.yml

test-liberty-health: ## Check Liberty server health
	@echo "$(GREEN)Checking Liberty health...$(NC)"
	cd $(ANSIBLE_DIR) && ansible liberty -m uri \
		-a "url=http://localhost:9080/health" \
		-i inventory/aws_ec2.yml

# ==================== Linting Commands ====================

lint: tf-fmt tf-validate ansible-lint ansible-syntax ## Run all linters
	@echo "$(GREEN)All linting checks passed!$(NC)"

lint-tf: ## Run Terraform linting with tflint
	cd $(TF_DIR) && tflint

lint-security: ## Run security scanning with tfsec
	tfsec infra/terraform/

# ==================== Utility Commands ====================

ssh-bastion: ## SSH to bastion host
	@BASTION_IP=$$(cd $(TF_DIR) && terraform output -raw bastion_public_ip) && \
	ssh -i ~/.ssh/liberty-platform-$(ENV).pem ec2-user@$$BASTION_IP

ssh-awx: ## SSH to AWX server via bastion
	@BASTION_IP=$$(cd $(TF_DIR) && terraform output -raw bastion_public_ip) && \
	AWX_IP=$$(cd $(TF_DIR) && terraform output -raw awx_private_ip) && \
	ssh -i ~/.ssh/liberty-platform-$(ENV).pem -J ec2-user@$$BASTION_IP ec2-user@$$AWX_IP

tunnel-awx: ## Create SSH tunnel to AWX
	@BASTION_IP=$$(cd $(TF_DIR) && terraform output -raw bastion_public_ip) && \
	AWX_IP=$$(cd $(TF_DIR) && terraform output -raw awx_private_ip) && \
	echo "$(GREEN)AWX available at http://localhost:8052$(NC)" && \
	ssh -i ~/.ssh/liberty-platform-$(ENV).pem -L 8052:$$AWX_IP:8052 ec2-user@$$BASTION_IP

tunnel-grafana: ## Create SSH tunnel to Grafana
	@BASTION_IP=$$(cd $(TF_DIR) && terraform output -raw bastion_public_ip) && \
	MON_IP=$$(cd $(TF_DIR) && terraform output -raw monitoring_private_ip) && \
	echo "$(GREEN)Grafana available at http://localhost:3000$(NC)" && \
	ssh -i ~/.ssh/liberty-platform-$(ENV).pem -L 3000:$$MON_IP:3000 ec2-user@$$BASTION_IP

clean: ## Clean up temporary files
	@echo "$(GREEN)Cleaning up...$(NC)"
	find . -name "*.tfplan" -delete
	find . -name ".terraform.lock.hcl" -delete
	find . -name "*.retry" -delete
	rm -rf infra/terraform/environments/*/.terraform

# ==================== Bootstrap Commands ====================

bootstrap-backend: ## Bootstrap Terraform backend (run once)
	@echo "$(GREEN)Bootstrapping Terraform backend...$(NC)"
	cd infra/terraform/backend && terraform init && terraform apply

bootstrap-secrets: ## Set up initial secrets in AWS
	@echo "$(GREEN)Creating secrets in AWS Secrets Manager...$(NC)"
	@read -sp "Enter AWX admin password: " AWX_PASS && \
	aws secretsmanager create-secret \
		--name liberty-platform/$(ENV)/awx-admin-password \
		--secret-string "$$AWX_PASS" \
		--region $(AWS_REGION)
	@read -sp "Enter Grafana admin password: " GRAFANA_PASS && \
	aws secretsmanager create-secret \
		--name liberty-platform/$(ENV)/grafana-admin-password \
		--secret-string "$$GRAFANA_PASS" \
		--region $(AWS_REGION)

# ==================== Documentation ====================

docs: ## Generate documentation
	@echo "$(GREEN)Documentation available in $(DOCS_DIR)/$(NC)"
	@ls -la $(DOCS_DIR)/

# ==================== CI/CD Helpers ====================

ci-lint: ## CI lint check (non-interactive)
	terraform fmt -check -recursive infra/terraform/
	cd infra/terraform/environments/dev && terraform init -backend=false && terraform validate
	cd infra/terraform/environments/prod && terraform init -backend=false && terraform validate
	cd $(ANSIBLE_DIR) && ansible-lint --force-color playbooks/ roles/ || true

ci-plan: ## CI plan (for PR checks)
	cd $(TF_DIR) && terraform init && terraform plan -input=false -no-color
