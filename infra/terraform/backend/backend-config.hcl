# Generated backend configuration
# Copy this to your environment's backend.tf

bucket       = "liberty-platform-terraform-state"
key          = "ENVIRONMENT/terraform.tfstate"  # Replace ENVIRONMENT
region       = "us-east-1"
use_lockfile = true
encrypt      = true
