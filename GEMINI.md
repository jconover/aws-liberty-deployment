# Project Overview

This repository contains a comprehensive DevOps platform for deploying and managing IBM WebSphere Liberty application servers on AWS. It uses a combination of Terraform for infrastructure as code, Ansible for configuration management, and GitHub Actions for CI/CD. The platform is designed to be modular, scalable, and secure, with separate environments for development and production.

## Key Technologies

*   **Infrastructure as Code:** Terraform
*   **Configuration Management:** Ansible
*   **CI/CD:** GitHub Actions
*   **Orchestration:** AWX (Ansible AWX)
*   **Monitoring:** Prometheus, Grafana, Alertmanager
*   **Cloud Provider:** AWS

## Architecture

The architecture consists of the following key components:

*   **VPC:** A multi-AZ VPC with public and private subnets.
*   **EC2 Instances:** Separate instances for bastion hosts, AWX, monitoring, and Liberty application servers.
*   **IAM Roles:** Fine-grained IAM roles for EC2 instances and GitHub Actions to ensure least-privilege access.
*   **Security Groups:** Network access rules to control traffic between components.
*   **S3:** Used for storing Terraform state and application artifacts.
*   **AWX:** Provides a web-based UI for managing and executing Ansible playbooks.
*   **Prometheus:** Collects metrics from all servers.
*   **Grafana:** Visualizes metrics with pre-built dashboards.
*   **Alertmanager:** Handles alerts from Prometheus.

# Building and Running

The project uses a `Makefile` to simplify common tasks.

## Initial Setup

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/jconover/aws-liberty-deployment.git
    cd aws-liberty-deployment
    ```

2.  **Bootstrap the Terraform backend:**
    ```bash
    make bootstrap-backend
    ```

3.  **Configure the environment:**
    ```bash
    cd infra/terraform/environments/dev
    cp terraform.tfvars.example terraform.tfvars
    # Edit terraform.tfvars with your values
    ```

## Infrastructure Deployment

*   **Plan changes:**
    ```bash
    make tf-plan ENV=dev
    ```

*   **Apply changes:**
    ```bash
    make tf-apply ENV=dev
    ```

## Application and Platform Deployment

*   **Deploy all components:**
    ```bash
    make deploy-all ENV=dev
    ```

*   **Deploy a specific application:**
    ```bash
    make deploy-app APP_NAME=myapp APP_VERSION=1.0.0 ENV=dev
    ```

## Testing

*   **Run all linters:**
    ```bash
    make lint
    ```

*   **Test connectivity to all hosts:**
    ```bash
    make test-connectivity ENV=dev
    ```

# Development Conventions

## Infrastructure

*   Terraform code is organized into modules for reusability.
*   Each environment (e.g., `dev`, `prod`) has its own Terraform workspace.
*   The `dev` environment is configured for cost-optimization.

## Configuration Management

*   Ansible roles are used to configure different server types (e.g., `awx`, `liberty`, `monitoring`).
*   Global variables are defined in `ansible/group_vars/all.yml`.
*   Role-specific defaults are in the `defaults/main.yml` file for each role.

## CI/CD

*   GitHub Actions are used to automate Terraform deployments.
*   The `main` branch is protected, and changes are applied via pull requests.
*   The `terraform-plan` workflow runs on every push to a feature branch.
*   The `terraform-apply` workflow is triggered by a push to `main` or can be manually dispatched.

## Security

*   Secrets are managed using AWS Secrets Manager.
*   IAM roles and security groups are configured to follow the principle of least privilege.
*   SSH access is restricted to a bastion host.
*   The `main` branch in GitHub is protected, and all changes require a pull request and review.
