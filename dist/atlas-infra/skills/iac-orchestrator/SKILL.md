---
name: iac-orchestrator
description: "Infrastructure as Code orchestration. Terraform/OpenTofu plans, cloud-init templates, state management, drift detection."
effort: high
---

# IaC Orchestrator

## When to Use
- Creating or modifying Terraform/OpenTofu configurations
- Generating cloud-init user-data for VM provisioning
- Managing Terraform state (plan, apply, import, state mv)
- Detecting infrastructure drift (planned vs actual)
- Reviewing IaC changes before apply

## Key Repositories

| Repo | Path | Purpose |
|------|------|---------|
| homelab-iac | `~/workspace_atlas/infrastructure/` | Proxmox IaC, Coder templates |
| synapse | `~/workspace_atlas/projects/atlas/synapse/` | App compose files |

## Process

### 1. Terraform Workflow
```bash
cd <terraform-dir>
terraform init                    # Initialize providers
terraform plan -out=tfplan        # Preview changes
terraform show tfplan             # Review plan details
# HITL GATE — get approval before apply
terraform apply tfplan            # Apply approved changes
terraform state list              # Verify state
```

### 2. Cloud-Init Templates
```yaml
#cloud-config
users:
  - name: dev
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    ssh_authorized_keys:
      - <key>
packages:
  - docker.io
  - python3
runcmd:
  - systemctl enable docker
```

### 3. Drift Detection
```bash
terraform plan -detailed-exitcode  # Exit 2 = drift detected
terraform refresh                  # Update state from reality
terraform show -json | jq '.values.root_module.resources[]'
```

## Safety Rules

- **NEVER** `terraform apply` without plan review + HITL approval
- **ALWAYS** backup state before `state mv` or `state rm`
- **ALWAYS** `terraform plan` before `apply` (never skip)
- Use `-target` sparingly — full plans are safer
- Lock state during operations (prevent concurrent access)
