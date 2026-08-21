# ==============================================================================
# Multi-Cloud Ephemeral Runners (AWS EC2 ASG + Azure VMSS)
# Scale-to-Zero runner management for QuocVanD-DevSecOpsLab
# ==============================================================================

SHELL := /bin/bash
.PHONY: help fmt lint aws-init aws-plan aws-apply aws-destroy azure-init azure-plan azure-apply azure-destroy clean

help: ## Show available commands and usage
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

fmt: ## Format all terraform code
	@echo "==> Formatting terraform files..."
	@terraform fmt -recursive

lint: fmt ## Check code formatting and run linters
	@echo "==> Validating terraform syntax..."
	@terraform -chdir=aws init -backend=false >/dev/null 2>&1 || true
	@terraform -chdir=aws validate
	@terraform -chdir=azure init -backend=false >/dev/null 2>&1 || true
	@terraform -chdir=azure validate
	@echo "==> All configs are looking good!"

# ------------------------------------------------------------------------------
# AWS EC2 ASG Ephemeral Runner Stack (ap-southeast-1 Singapore)
# ------------------------------------------------------------------------------
aws-init: ## Init terraform for AWS runner stack
	@echo "==> Initializing AWS runner stack..."
	@terraform -chdir=aws init

aws-plan: ## Plan AWS runner infrastructure (Spot ASG + Lambda scaler)
	@echo "==> Planning AWS runner deployment..."
	@terraform -chdir=aws plan

aws-apply: ## Deploy AWS runner stack (keep min_size at 0 for zero idle cost)
	@echo "==> Deploying AWS runner infrastructure..."
	@terraform -chdir=aws apply -auto-approve

aws-destroy: ## Tear down AWS runner stack completely
	@echo "==> Destroying AWS runner stack..."
	@terraform -chdir=aws destroy -auto-approve

# ------------------------------------------------------------------------------
# Azure VMSS Ephemeral Runner Stack (southeastasia Singapore)
# ------------------------------------------------------------------------------
azure-init: ## Init terraform for Azure runner stack
	@echo "==> Initializing Azure runner stack..."
	@terraform -chdir=azure init

azure-plan: ## Plan Azure runner infrastructure (Spot VMSS + Function scaler)
	@echo "==> Planning Azure runner deployment..."
	@terraform -chdir=azure plan

azure-apply: ## Deploy Azure runner stack to southeastasia
	@echo "==> Deploying Azure runner infrastructure..."
	@terraform -chdir=azure apply -auto-approve

azure-destroy: ## Tear down Azure runner stack completely
	@echo "==> Destroying Azure runner stack..."
	@terraform -chdir=azure destroy -auto-approve

clean: ## Clean up local temp files, state backups and cache
	@echo "==> Cleaning cache..."
	@find . -type d -name ".terraform" -exec rm -rf {} +
	@find . -name "*.tfstate*" -delete
	@find . -name "__pycache__" -exec rm -rf {} +
	@find . -name "*.zip" -delete
	@echo "==> Done cleaning."
