# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Ansible repository for managing Komodo infrastructure and applications. This is a hub-and-spoke container orchestration platform where Komodo Core acts as the central controller, coordinating deployments across multiple Periphery nodes connected via Tailscale VPN.

Key components:
- **Komodo Core**: Central management server with web interface (port 9120) and MongoDB
- **Komodo Periphery**: Distributed agent nodes for executing deployments (port 8120)
- **Secret Management**: Pluggable backend system (Infisical by default, 1Password optional)
- **Application Stacks**: GitOps-driven application deployment from GitHub repositories

## Development Commands

### Setup and Installation

```bash
# Install all tools and dependencies (mise + pre-commit)
mise install
mise run hooks-install

# Install Ansible dependencies
cd ansible
ansible-galaxy install -r requirements.yml
```

### Linting and Quality Checks

```bash
# Run all pre-commit hooks manually
mise run hooks-run

# Lint YAML files
mise run yaml-lint

# Lint Ansible playbooks and roles
mise run ansible-lint

# Lint Markdown files
mise run markdown-lint
```

### Ansible Operations

All Ansible commands must be run from the `ansible/` directory.

```bash
# Test SSH connectivity to all hosts
ansible all -i inventory/all.yml -m ping

# Run the complete deployment playbook
ansible-playbook -i inventory/all.yml site.yml

# Run specific playbooks with tags
ansible-playbook -i inventory/all.yml site.yml --tags docker
ansible-playbook -i inventory/all.yml site.yml --tags core
ansible-playbook -i inventory/all.yml site.yml --tags auth
ansible-playbook -i inventory/all.yml site.yml --tags periphery

# Check mode (dry run)
ansible-playbook -i inventory/all.yml site.yml --check

# Override variables
ansible-playbook -i inventory/all.yml site.yml -e enable_komodo_op=false
```

### Secret Management

```bash
# Initialize Infisical for secret scanning
mise run infisical-init

# Scan for secrets using baseline
mise run infisical-scan

# Update baseline when adding known false positives
mise run infisical-baseline-update
```

### Changelog

```bash
# Update CHANGELOG.md using git-cliff
mise run changelog
```

## Architecture

### Directory Structure

```
ansible/
├── inventory/all.yml      # Single source of truth for configuration
├── playbooks/             # Sequential deployment playbooks (01-05)
│   ├── 01_docker.yml
│   ├── 02_komodo_core.yml
│   ├── 03_komodo_auth.yml
│   ├── 04_komodo_periphery.yml
│   ├── 05_app_syncs.yml
│   └── optional/          # Optional integrations
│       ├── 05_bootstrap_komodo_op.yml  # 1Password integration
│       ├── 06_deploy_komodo_op.yml     # 1Password integration
│       └── README.md
├── roles/                 # Custom and external Ansible roles
│   ├── komodo/           # Komodo Core deployment role
│   ├── komodo_auth/      # Authentication management role (pluggable backends)
│   ├── geerlingguy.docker/  # External role
│   └── bpbradley.komodo/    # External role
├── tasks/                # Shared task files
│   └── infisical-secret-lookup.yml  # Reusable Infisical integration
├── site.yml              # Master orchestration playbook
├── ansible.cfg           # Ansible configuration
└── requirements.yml      # Ansible dependencies
```

### Configuration

**Single source of truth**: `ansible/inventory/all.yml`

This file contains:
- Host definitions (control, core, periphery groups)
- Network settings (Tailscale IPs)
- Komodo Core and Periphery configuration
- Authentication credentials (via 1Password lookups)
- Git repository settings for GitOps
- Resource sync repository configuration

### GitOps Workflow

1. **komodo-resource-syncs**: Meta-sync repository containing `syncs.toml` that defines all resource syncs
2. **komodo-op-sync**: Infrastructure deployment (auto-deploy) for 1Password Connect integration
3. **komodo-app-stacks**: Application deployments (manual deploy for safety)

### Deployment Flow

The `site.yml` playbook orchestrates deployment in this order:
1. Install Docker on all nodes
2. Deploy Komodo Core (with MongoDB)
3. Initialize authentication (admin user, API keys)
4. Deploy Komodo Periphery agents
5. Bootstrap komodo-op variables (if enabled)
6. Deploy komodo-op stack (if enabled)

All playbooks are idempotent and can be safely run multiple times.

## Important Notes

### 1Password Integration

- Uses `community.general.onepassword` lookup plugin
- Requires `op` CLI to be authenticated before running playbooks
- Authentication credentials are stored in 1Password vault "Homelab Ansible"
- If deploying to fresh Komodo with stale API keys in 1Password, use `komodo_auth_force_recreate=true`

### Pre-commit Hooks

Pre-commit hooks are configured to run:
- trailing-whitespace, end-of-file-fixer
- YAML syntax checking
- Large file detection
- Shebang script validation
- Private key detection
- AWS credentials detection
- ansible-lint
- yamllint

### Tool Management

This project uses **mise** (formerly rtx) for tool version management. All tools are defined in `.mise.toml` including:
- ansible-core 2.19.1
- python 3.13.7
- pre-commit 4.3.0
- yamllint, markdownlint-cli2, actionlint
- git-cliff for changelog generation

### Working Directory

Always run Ansible commands from the `ansible/` directory. The ansible.cfg file is configured to:
- Use `inventory/hosts.yml` by default (note: actual inventory is `all.yml`)
- Disable host key checking for Tailscale networks
- Enable fact caching and performance optimizations
