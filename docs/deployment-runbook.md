# Komodo Infrastructure Deployment Runbook

This runbook documents the deployment workflow for Komodo infrastructure using Ansible.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Setup](#setup)
- [Deployment Workflows](#deployment-workflows)
- [Individual Components](#individual-components)
- [Secret Management & GitOps](#secret-management--gitops)
- [Upgrade & Management](#upgrade--management)
- [Maintenance](#maintenance)
- [Advanced Operations](#advanced-operations)

## Prerequisites

- Ansible installed (see Setup section)
- SSH access to all target hosts
- Inventory configured in `ansible/inventory/all.yml`
- Required secrets/credentials available

## Setup

### Install Ansible Dependencies

```bash
mise run install
```

This installs all required Ansible collections and dependencies.

### Verify Connectivity

Check that all hosts are reachable:

```bash
cd ansible && ansible all -i inventory/all.yml -m ping
```

## Deployment Workflows

### Complete Deployment (Recommended)

Run the full deployment sequence in one command:

```bash
cd ansible && ansible-playbook -i inventory/all.yml site.yml
```

**What this does:**

1. Installs Docker on all nodes
2. Deploys Komodo Core
3. Initializes authentication
4. Deploys Komodo Periphery nodes

**Note:** This does NOT include `komodo-op` (secret management) - that must be run separately (see below).

### Dry Run (Check Mode)

See what would change without making any modifications:

```bash
cd ansible && ansible-playbook -i inventory/all.yml site.yml --check --diff
```

## Individual Components

Deploy components individually in this order:

### 1. Install Docker

Installs Docker on all nodes (required first step):

```bash
cd ansible && ansible-playbook -i inventory/all.yml playbooks/01_docker.yml
```

### 2. Deploy Komodo Core

Deploys Komodo Core with MongoDB (requires Docker):

```bash
cd ansible && ansible-playbook -i inventory/all.yml playbooks/02_komodo_core.yml
```

**Services deployed:**

- Komodo Core (port 9120)
- MongoDB

### 3. Initialize Authentication

Sets up authentication for Komodo (requires Core to be running):

```bash
cd ansible && ansible-playbook -i inventory/all.yml playbooks/03_komodo_auth.yml
```

### 4. Deploy Komodo Periphery

Deploys Komodo Periphery agents on remote nodes (requires auth):

```bash
cd ansible && ansible-playbook -i inventory/all.yml playbooks/04_komodo_periphery.yml
```

**Services deployed:**

- Komodo Periphery (port 8120)

## Secret Management & GitOps

These steps are **manual** and run separately after the main deployment.

### Deploy komodo-op (1Password Connect)

Two-step process:

**Step 1: Bootstrap Variables**

```bash
cd ansible && ansible-playbook -i inventory/all.yml playbooks/05_bootstrap_komodo_op.yml
```

**Step 2: Deploy komodo-op Stack**

```bash
cd ansible && ansible-playbook -i inventory/all.yml playbooks/06_deploy_komodo_op.yml
```

### Setup Application Resource Syncs

Enable GitOps for applications (run after komodo-op):

```bash
cd ansible && ansible-playbook -i inventory/all.yml playbooks/07_app_syncs.yml
```

## Upgrade & Management

### Upgrade Komodo Core

Pull latest images and upgrade Core:

```bash
cd ansible && ansible-playbook -i inventory/all.yml playbooks/02_komodo_core.yml --tags upgrade
```

### Upgrade Komodo Periphery

Update all Periphery nodes:

```bash
cd ansible && ansible-playbook -i inventory/all.yml playbooks/04_komodo_periphery.yml -e komodo_action=update
```

### Upgrade Everything

Full upgrade of Core and all Periphery nodes:

```bash
# Upgrade Core
cd ansible && ansible-playbook -i inventory/all.yml playbooks/02_komodo_core.yml

# Upgrade Periphery
cd ansible && ansible-playbook -i inventory/all.yml playbooks/04_komodo_periphery.yml -e komodo_action=update
```

### Uninstall Komodo Periphery

Remove Komodo Periphery from nodes:

```bash
cd ansible && ansible-playbook -i inventory/all.yml playbooks/04_komodo_periphery.yml -e komodo_action=uninstall
```

## Maintenance

### Check Service Status

Verify status of all Komodo services:

```bash
cd ansible && ansible-playbook -i inventory/all.yml playbooks/status.yml
```

### Code Quality Checks

**Run ansible-lint:**

```bash
cd ansible && ansible-lint
```

**Run yamllint:**

```bash
yamllint ansible/ .github/workflows/
```

**Run all linters:**

```bash
cd ansible && ansible-lint && yamllint ansible/ .github/workflows/
```

### Cleanup

Remove temporary files and caches:

```bash
find . -name "*.pyc" -delete
find . -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
rm -rf ansible/.ansible/
```

## Advanced Operations

### Run Specific Playbook

Run any playbook with custom options:

```bash
cd ansible && ansible-playbook -i inventory/all.yml playbooks/<PLAYBOOK_NAME> [OPTIONS]
```

**Examples:**

```bash
# Run Docker installation with verbose output
cd ansible && ansible-playbook -i inventory/all.yml playbooks/01_docker.yml -v

# Run Core deployment in check mode
cd ansible && ansible-playbook -i inventory/all.yml playbooks/02_komodo_core.yml --check --diff

# Target specific host
cd ansible && ansible-playbook -i inventory/all.yml playbooks/04_komodo_periphery.yml --limit periphery-1
```

### Common Ansible Options

- `--check` - Dry run, show what would change
- `--diff` - Show differences in files
- `-v`, `-vv`, `-vvv` - Increase verbosity
- `--limit HOST` - Target specific host(s)
- `--tags TAG` - Run only specific tags
- `--skip-tags TAG` - Skip specific tags
- `-e VAR=VALUE` - Set extra variables

## Deployment Sequence Reference

**Full deployment order:**

1. **Docker** (`01_docker.yml`) - Install Docker engine
2. **Core** (`02_komodo_core.yml`) - Deploy Komodo Core + MongoDB
3. **Auth** (`03_komodo_auth.yml`) - Initialize authentication
4. **Periphery** (`04_komodo_periphery.yml`) - Deploy Periphery agents
5. **[Manual] komodo-op Bootstrap** (`05_bootstrap_komodo_op.yml`) - Prepare 1Password integration
6. **[Manual] komodo-op Deploy** (`06_deploy_komodo_op.yml`) - Deploy 1Password Connect
7. **[Manual] App Syncs** (`07_app_syncs.yml`) - Configure GitOps resource syncs

## Quick Reference

```bash
# Initial setup
./scripts/setup-ansible.sh

# Full deployment
cd ansible && ansible-playbook -i inventory/all.yml site.yml

# Manual steps (run after main deployment)
cd ansible && ansible-playbook -i inventory/all.yml playbooks/05_bootstrap_komodo_op.yml
cd ansible && ansible-playbook -i inventory/all.yml playbooks/06_deploy_komodo_op.yml
cd ansible && ansible-playbook -i inventory/all.yml playbooks/07_app_syncs.yml

# Upgrades
cd ansible && ansible-playbook -i inventory/all.yml playbooks/02_komodo_core.yml
cd ansible && ansible-playbook -i inventory/all.yml playbooks/04_komodo_periphery.yml -e komodo_action=update
```
