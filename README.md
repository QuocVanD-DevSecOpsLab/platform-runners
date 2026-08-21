# Multi-Cloud Ephemeral Runners (AWS EC2 ASG & Azure VMSS)

> **Scale-to-Zero ($0 Idle Cost)** GitHub Actions Runner Infrastructure for [QuocVanD-DevSecOpsLab](https://github.com/QuocVanD-DevSecOpsLab).

This repository manages on-demand ephemeral self-hosted runners across **AWS** (`ap-southeast-1` Singapore) and **Azure** (`southeastasia` Singapore) using keyless OIDC authentication.

---

## Why Ephemeral Runners & Scale-to-Zero?

Standard self-hosted runners run 24/7 on static VMs, which costs money even when idle and suffers from tool drift/cache contamination.  
Here, we use **Just-In-Time (JIT) Ephemeral Runners**:
1. **0 instances at rest**: Both AWS ASG and Azure VMSS are kept at `0` capacity.
2. **On-Demand Scaling**: When a GitHub workflow queues a job, a lightweight webhook (AWS Lambda / Azure Function) increases pool capacity by 1.
3. **Spot Pricing**: Uses AWS EC2 Spot and Azure Spot instances (80-90% discount).
4. **Single-Job Execution**: Each VM registers with `--ephemeral`, runs only 1 job, unregisters itself, and immediately self-terminates.

```text
[GitHub Workflow Queued] ---> [Cloud Webhook Listener] ---> [Scale Pool from 0 -> 1]
                                                                     |
                                                          [VM boots with Spot]
                                                                     |
                                                          [Executes 1 Job (--ephemeral)]
                                                                     |
                                                          [Instance Self-Terminates]
                                                                     |
                                                          [Pool returns to 0 instances ($0/mo)]
```

---

## Repository Structure

```text
.
├── Makefile                     # Helper commands (plan, apply, destroy, lint)
├── .github/
│   └── workflows/
│       ├── test-aws-runner.yml  # Test workflow running on [self-hosted, aws-spot]
│       └── test-azure-runner.yml# Test workflow running on [self-hosted, azure-spot]
│
├── aws/                         # AWS Ephemeral Spot Runner Stack (ap-southeast-1)
│   ├── modules/
│   │   ├── oidc/                # IAM OIDC Provider & Trust Role
│   │   ├── asg-runner/          # EC2 Spot Launch Template & Auto Scaling Group (min=0)
│   │   └── webhook-scaler/      # API Gateway + Lambda Webhook Listener
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
│
└── azure/                       # Azure Ephemeral Spot Runner Stack (southeastasia)
    ├── modules/
    │   ├── oidc-workload-id/    # Entra ID App & Federated Credentials
    │   ├── vmss-runner/         # Spot VMSS (min=0) + Cloud-Init
    │   └── webhook-scaler/      # Consumption Function App Webhook Listener
    ├── main.tf
    ├── variables.tf
    └── outputs.tf
```

---

## Prerequisites

- **AWS CLI** configured (`033781183622` in `ap-southeast-1`)
- **Azure CLI** logged in (`VDQ-AZURE-SEC-LAB` in `southeastasia`)
- **Terraform** >= 1.5.0

---

## Quickstart & Deployment

### 1. Deploy AWS Runner Stack
```bash
make aws-init
make aws-plan
make aws-apply
```
Outputs to note:
- `github_oidc_role_arn`: Use this in your GitHub workflows for AWS credentials.
- `webhook_endpoint_url`: Add to GitHub Org webhooks.

### 2. Deploy Azure Runner Stack
```bash
make azure-init
make azure-plan
make azure-apply
```
Outputs to note:
- `azure_client_id`: Entra ID Application ID for GitHub Actions `azure/login`.
- `azure_webhook_endpoint_url`: Add to GitHub Org webhooks.

### 3. Add Webhook to GitHub Org
Go to `https://github.com/organizations/QuocVanD-DevSecOpsLab/settings/hooks`:
1. Add AWS Webhook URL & Azure Webhook URL.
2. Select Content type: `application/json`.
3. Choose "Let me select individual events" -> check **Workflow jobs**.
4. Save webhook.

---

## Triggering Runners in Workflows

### Target AWS Spot Runner:
```yaml
jobs:
  build:
    runs-on: [self-hosted, aws-spot]
    steps:
      - uses: actions/checkout@v4
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::033781183622:role/devsecops-runners-mgmt-github-actions-role
          aws-region: ap-southeast-1
      - run: docker build -t myapp .
```

### Target Azure Spot Runner:
```yaml
jobs:
  build:
    runs-on: [self-hosted, azure-spot]
    steps:
      - uses: actions/checkout@v4
      - uses: azure/login@v2
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: "fdf0b2be-d187-4753-92db-b35388d55676"
          subscription-id: "7d3746c5-7456-498a-b9ea-088c845d696d"
      - run: az account show
```
