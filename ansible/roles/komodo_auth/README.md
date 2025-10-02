# komodo_auth Role

Ansible role for managing Komodo authentication including admin users, service users, and API credentials with pluggable secret backend support.

## Features

- **Backend Abstraction**: Supports multiple secret management backends (Infisical, 1Password, Ansible Vault)
- **Idempotent**: Safe to run multiple times
- **Service User Management**: Creates dedicated service users for automation
- **API Key Generation**: Generates and securely stores API credentials
- **Force Recreation**: Override existing credentials when needed

## Supported Secret Backends

### 1. Infisical (Default)
Modern open-source secret management platform with CLI and Ansible collection support.

**Requirements:**
- `infisical` CLI installed
- Environment variables set:
  - `INFISICAL_UNIVERSAL_AUTH_CLIENT_ID`
  - `INFISICAL_UNIVERSAL_AUTH_CLIENT_SECRET`

**Configuration:**
```yaml
komodo_auth_secret_backend: "infisical"
komodo_auth_infisical_project_id: "your-project-id"
komodo_auth_infisical_env: "prod"
komodo_auth_infisical_path: "/komodo"
```

### 2. 1Password (Legacy)
Enterprise password manager with CLI support.

**Requirements:**
- `op` CLI installed and authenticated

**Configuration:**
```yaml
komodo_auth_secret_backend: "1password"
komodo_auth_1password_vault: "Homelab Ansible"
komodo_auth_1password_item: "Komodo"
```

### 3. Ansible Vault (Future)
Ansible's built-in encryption system (planned support).

## Usage

### Basic Usage

```yaml
- hosts: localhost
  roles:
    - role: komodo_auth
```

### With Force Recreation

```bash
ansible-playbook playbooks/03_komodo_auth.yml -e komodo_auth_force_recreate=true
```

### Switching Backends

Update `ansible/roles/komodo_auth/defaults/main.yml`:

```yaml
komodo_auth_secret_backend: "infisical"  # or "1password"
```

## Variables

### Core Settings (from inventory)

```yaml
# Connection settings
komodo_auth_base_url: "http://komodo-core:9120"

# Admin credentials (read from secret backend)
komodo_auth_admin_username: "admin"
komodo_auth_admin_password: "{{ secret_lookup }}"

# Service user configuration
komodo_auth_service_user: "komodo-automation"
komodo_auth_service_user_description: "Service user for automated deployments"
komodo_auth_api_key_name: "deployment-api-key"
```

### Role Defaults

```yaml
# Backend selection
komodo_auth_secret_backend: "infisical"

# Behavior
komodo_auth_force_recreate: false
komodo_auth_max_retries: 5
komodo_auth_retry_delay: 2
komodo_auth_timeout: 30

# Backend-specific settings
# (see defaults/main.yml for complete list)
```

## Architecture

### Backend Interface

Each backend must implement two operations:

#### 1. Check Operation (`operation: "check"`)
- **Purpose**: Verify if credentials already exist
- **Output**: Sets `komodo_auth_existing_api_key` fact with `.stdout` property

#### 2. Store Operation (`operation: "store"`)
- **Purpose**: Save generated credentials to secret backend
- **Input**: `komodo_auth_api_key` and `komodo_auth_api_secret` facts
- **Verification**: Reads back credentials to confirm storage

### Task Flow

```
main.yml
├── Check existing credentials (backend check operation)
├── Skip if exists (unless force_recreate=true)
├── Wait for Komodo Core
├── Test admin user login
├── Create admin user (if needed)
├── Login as admin
├── Create/find service user
├── Create API key for service user
└── Store credentials (backend store operation)
```

## Troubleshooting

### Silent Failure on Fresh Deployments

**Symptom**: Playbook skips authentication setup on fresh Komodo instance.

**Cause**: Stale credentials exist in secret backend from previous deployment.

**Solution**:
```bash
# Option 1: Force recreation
ansible-playbook playbooks/03_komodo_auth.yml -e komodo_auth_force_recreate=true

# Option 2: Manually delete stale credentials from your secret backend
```

### Infisical Authentication Errors

**Symptom**: "Missing Infisical authentication credentials" error.

**Solution**: Ensure environment variables are set:
```bash
export INFISICAL_UNIVERSAL_AUTH_CLIENT_ID="your-client-id"
export INFISICAL_UNIVERSAL_AUTH_CLIENT_SECRET="your-client-secret"
```

### Backend-Specific Issues

For backend-specific troubleshooting, see:
- `tasks/backends/infisical.yml` - Infisical implementation
- `tasks/backends/1password.yml` - 1Password implementation

## Migration Guide

### From 1Password to Infisical

1. **Export existing credentials** from 1Password (manual step)

2. **Update inventory** (`ansible/inventory/all.yml`):
   ```yaml
   # Comment out 1Password lookups
   # komodo_auth_admin_username: "{{ lookup('community.general.onepassword', ...) }}"

   # Add Infisical lookups
   komodo_auth_admin_username: "{{ lookup('infisical.vault.read_secrets', ...).value }}"
   ```

3. **Set backend** in role defaults or inventory:
   ```yaml
   komodo_auth_secret_backend: "infisical"
   ```

4. **Import credentials to Infisical**:
   ```bash
   infisical secrets set KOMODO_ADMIN_USERNAME=admin \
     --projectId="..." --env="prod" --path="/komodo"
   ```

5. **Run playbook with force recreation**:
   ```bash
   ansible-playbook playbooks/03_komodo_auth.yml -e komodo_auth_force_recreate=true
   ```

## Files

```
komodo_auth/
├── defaults/main.yml           # Role defaults and backend config
├── tasks/
│   ├── main.yml                # Main orchestration logic
│   ├── create_admin_user.yml   # Admin user creation
│   ├── manage_service_user.yml # Service user management
│   ├── create_api_key.yml      # API key generation
│   └── backends/               # Pluggable secret backends
│       ├── 1password.yml       # 1Password implementation
│       └── infisical.yml       # Infisical implementation
└── README.md                   # This file
```

## Examples

See `ansible/playbooks/03_komodo_auth.yml` for a complete usage example.

## License

Same as parent project.
