# Copilot Instructions for hello-komodo

## Project Overview

**Type**: Ansible infrastructure-as-code repository  
**Purpose**: Automated deployment and management of Komodo container orchestration platform  
**Size**: ~72 YAML files, primarily Ansible playbooks and roles  
**Languages/Frameworks**: Ansible 2.19+, Python 3.13, YAML configuration  
**Architecture**: Hub-and-spoke deployment with Komodo Core (central controller) and Komodo Periphery (distributed agents)

### Key Components

- **Komodo Core**: Central management server with web UI (port 9120) and MongoDB
- **Komodo Periphery**: Distributed agent nodes for deployments (port 8120)
- **Secret Management**: Pluggable backends (Infisical default, 1Password optional)
- **GitOps**: Application deployment via GitHub repository syncs

## Build, Test, and Validation Commands

### Initial Setup

**ALWAYS run these commands from the repository root unless otherwise specified:**

```bash
# Install mise tool manager and dependencies (if mise is available)
mise install
mise run hooks-install

# Install Ansible collections and roles (run from ansible/ directory)
cd ansible
ansible-galaxy collection install -r requirements.yml
ansible-galaxy role install -r requirements.yml
```

**Note**: In restricted environments where `mise` is unavailable, ensure Python 3.13+ and Ansible 2.19+ are installed manually. The project uses mise for tool version management but Ansible can be used directly if mise is not available.

### Validation and Linting

**ALWAYS run linting before committing changes. These commands work in any environment:**

```bash
# Lint YAML files (works from repo root or ansible/ directory)
yamllint .
# Or specifically for ansible directory:
cd ansible && yamllint .

# Syntax check Ansible playbooks (MUST run from ansible/ directory)
cd ansible && ansible-playbook --syntax-check site.yml

# List playbook tasks without execution (safe dry-run)
cd ansible && ansible-playbook --list-tasks site.yml

# Run pre-commit hooks manually (if pre-commit is installed)
pre-commit run --all-files
```

**Important**: The `yamllint` command returns warnings for external role files (in `ansible/roles/geerlingguy.docker` and `ansible/roles/bpbradley.komodo`). These warnings are from third-party roles and can be ignored. Focus on warnings in files you're editing.

### Ansible Operations

**CRITICAL**: All Ansible playbook commands MUST be run from the `ansible/` directory:

```bash
cd ansible

# Test connectivity (requires SSH access to hosts)
ansible all -i inventory/all.yml -m ping

# Run complete deployment (requires infrastructure access)
ansible-playbook -i inventory/all.yml site.yml

# Dry run to see what would change (safe, no modifications)
ansible-playbook -i inventory/all.yml site.yml --check --diff

# Run specific tags
ansible-playbook -i inventory/all.yml site.yml --tags docker
ansible-playbook -i inventory/all.yml site.yml --tags core
```

**Note**: Actual deployment commands require SSH access to target infrastructure and will fail in CI/sandbox environments. Use `--syntax-check` or `--list-tasks` for validation without infrastructure access.

### Secret Scanning

```bash
# Initialize Infisical secret scanning (if Infisical CLI available)
mise run infisical-init

# Scan for secrets with baseline
mise run infisical-scan
```

## Project Layout and Architecture

### Directory Structure

```
.
├── .github/
│   └── workflows/
│       └── use-sync-labels.yml    # Weekly label sync workflow
├── ansible/                        # ALL Ansible content lives here
│   ├── .ansible-lint              # Ansible linting rules
│   ├── .yamllint                  # YAML linting rules (160 char max)
│   ├── ansible.cfg                # Ansible configuration (IMPORTANT)
│   ├── inventory/
│   │   ├── all.yml                # SINGLE SOURCE OF TRUTH for all config
│   │   └── dynamic_tailscale.py   # Dynamic inventory script
│   ├── playbooks/
│   │   ├── 01_docker.yml          # Install Docker
│   │   ├── 02_komodo_core.yml     # Deploy Komodo Core
│   │   ├── 03_komodo_auth.yml     # Initialize authentication
│   │   ├── 04_komodo_periphery.yml # Deploy Periphery agents
│   │   ├── 05_app_syncs.yml       # Configure GitOps syncs
│   │   └── optional/              # Optional integrations
│   │       ├── 05_bootstrap_komodo_op.yml  # 1Password bootstrap
│   │       └── 06_deploy_komodo_op.yml     # 1Password deployment
│   ├── roles/
│   │   ├── komodo/                # Komodo Core deployment role
│   │   ├── komodo_auth/           # Auth management (pluggable backends)
│   │   ├── geerlingguy.docker/    # External Docker role (DO NOT EDIT)
│   │   └── bpbradley.komodo/      # External Periphery role (DO NOT EDIT)
│   ├── tasks/
│   │   └── infisical-secret-lookup.yml  # Reusable secret lookup
│   ├── requirements.yml           # Ansible dependencies
│   └── site.yml                   # MASTER playbook - orchestrates all
├── docs/                          # Documentation
│   ├── deployment-runbook.md      # Detailed deployment steps
│   ├── secret-management.md       # Secret backend configuration
│   └── developer-tools.md         # Tool setup guide
├── mise-tasks/                    # Mise task definitions
│   ├── ansible/install            # Install Ansible collections/roles
│   └── install                    # Main install task
├── .mise.toml                     # Tool version management
├── .pre-commit-config.yaml        # Pre-commit hook configuration
├── requirements.txt               # Python dependencies
└── CLAUDE.md                      # Detailed project documentation
```

### Configuration Files

- **`.yamllint`**: YAML linting with 160 character line limit, warnings level
- **`ansible/.ansible-lint`**: Ansible-lint with safety profile
- **`ansible/ansible.cfg`**: Disables host key checking, enables fact caching
- **`.pre-commit-config.yaml`**: Runs trailing-whitespace, yaml checks, ansible-lint, yamllint

### Key Facts

1. **Working Directory**: ALWAYS run Ansible commands from `ansible/` directory (commands fail from repo root)
2. **Single Source of Truth**: All configuration is in `ansible/inventory/all.yml`
3. **Idempotent**: All playbooks can be safely run multiple times
4. **Sequential Playbooks**: Deployment order matters: docker → core → auth → periphery
5. **External Roles**: `geerlingguy.docker` and `bpbradley.komodo` are external - DO NOT modify
6. **Secret Backends**: Pluggable system - Infisical (default) or 1Password (optional)

### Validation Pipeline

**GitHub Actions**: Single workflow `.github/workflows/use-sync-labels.yml` for label synchronization (weekly cron)

**Pre-commit Hooks** (run on every commit):

1. `trailing-whitespace` - Remove trailing whitespace
2. `end-of-file-fixer` - Ensure files end with newline
3. `check-yaml` - Validate YAML syntax
4. `check-added-large-files` - Prevent large files
5. `detect-private-key` - Prevent committing private keys
6. `detect-aws-credentials` - Prevent AWS credential leaks
7. `ansible-lint` - Lint Ansible playbooks
8. `yamllint` - Lint YAML files

**Manual Validation Steps**:

```bash
# Step 1: YAML linting (from ansible/ directory)
cd ansible && yamllint .

# Step 2: Ansible syntax check
cd ansible && ansible-playbook --syntax-check site.yml

# Step 3: List tasks (verify structure)
cd ansible && ansible-playbook --list-tasks site.yml

# Step 4: Dry run (if you have access to inventory hosts)
cd ansible && ansible-playbook -i inventory/all.yml site.yml --check
```

### Deployment Flow

The `site.yml` playbook orchestrates deployment in this exact order:

1. **Docker** - Install Docker on all nodes (tag: `docker`, `bootstrap`)
2. **Core** - Deploy Komodo Core + MongoDB (tag: `core`)
3. **Auth** - Initialize authentication (tag: `auth`)
4. **Periphery** - Deploy Periphery agents (tag: `periphery`)
5. **Optional**: komodo-op for 1Password integration (tag: `komodo-op`, `secrets`, `optional`)

### Common Issues and Workarounds

**Issue**: `ansible-galaxy install` fails with network errors  
**Workaround**: This is expected in restricted sandbox environments. Collections must be pre-installed or environment must have internet access.

**Issue**: Dynamic inventory script `dynamic_tailscale.py` causes warnings  
**Workaround**: This is normal - warnings can be ignored. Script requires Tailscale access which isn't available in CI/sandbox.

**Issue**: Playbooks fail when testing locally without infrastructure  
**Workaround**: Use `--syntax-check` or `--list-tasks` for validation without requiring actual hosts.

**Issue**: Line length warnings from external roles  
**Workaround**: Warnings from files in `ansible/roles/geerlingguy.docker/` and `ansible/roles/bpbradley.komodo/` are from external roles - ignore them.

### Root Directory Files

- `.gitignore` - Excludes `.ansible/`, `.venv/`, `*.retry`, `.mcp.json`
- `.mise.toml` - Tool versions: ansible-core 2.19.1, python 3.13.7, pre-commit 4.3.0
- `CLAUDE.md` - Comprehensive project documentation (183 lines)
- `README.md` - Basic project overview
- `ansible/README.md` - Detailed ansible documentation (350 lines)
- `CHANGELOG.md` - Project changelog
- `requirements.txt` - Python deps: ansible-dev-tools, infisicalsdk
- `cliff.toml` - git-cliff changelog configuration
- `renovate.json` - Renovate bot configuration

### Important Ansible Configuration (ansible.cfg)

```ini
[defaults]
inventory = inventory          # Default inventory path
roles_path = roles:~/.ansible/roles
host_key_checking = False      # CRITICAL: Disabled for Tailscale networks
gathering = smart              # Smart fact gathering
fact_caching = memory          # In-memory fact cache

[ssh_connection]
ssh_args = -o ControlMaster=auto -o ControlPersist=60s -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no
pipelining = True              # Performance optimization
```

## Instructions for Coding Agents

1. **Trust these instructions**: Only search for additional information if instructions are incomplete or incorrect
2. **Working directory**: ALWAYS `cd ansible` before running Ansible commands
3. **Validation sequence**: yamllint → syntax-check → list-tasks (in that order)
4. **DO NOT modify**: External roles in `ansible/roles/geerlingguy.docker/` or `ansible/roles/bpbradley.komodo/`
5. **Line length**: Keep YAML lines under 160 characters (warning level, not error)
6. **Idempotency**: Ensure playbook changes remain idempotent (safe to run multiple times)
7. **Testing without infrastructure**: Use `--syntax-check` and `--list-tasks` flags - they work without host access
8. **Configuration changes**: Edit `ansible/inventory/all.yml` for all deployment configuration
9. **Secret backend**: Default is Infisical - check `ansible/roles/komodo_auth/` for backend abstraction
10. **Pre-commit**: Run `pre-commit run --all-files` before finalizing changes (if available)
