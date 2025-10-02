# Optional Playbooks

This directory contains playbooks for optional integrations that are not part of the core Komodo deployment.

## 1Password Connect Integration (komodo-op)

These playbooks are for deploying **komodo-op**, the 1Password Connect integration for Komodo:

- **`05_bootstrap_komodo_op.yml`** - Bootstrap Komodo global variables for komodo-op
- **`06_deploy_komodo_op.yml`** - Deploy komodo-op stack and resource syncs

### When to Use

Use these playbooks if you want to:
- Use 1Password Connect as your secret management solution
- Deploy the komodo-op application stack
- Sync secrets from 1Password to Komodo global variables

### Prerequisites

1. **1Password Connect** configured and running
2. **1Password CLI** authenticated (`op` command available)
3. **enable_komodo_op: true** in `ansible/inventory/all.yml`
4. **Secret backend** set to `1password` in `ansible/roles/komodo_auth/defaults/main.yml`

### Usage

```bash
# Bootstrap variables (run once)
ansible-playbook -i inventory/all.yml playbooks/optional/05_bootstrap_komodo_op.yml

# Deploy komodo-op stack
ansible-playbook -i inventory/all.yml playbooks/optional/06_deploy_komodo_op.yml
```

## Alternative: Infisical (Default)

If you're using **Infisical** for secret management (the default configuration), you **do not need these playbooks**. The core authentication playbook ([03_komodo_auth.yml](../03_komodo_auth.yml)) handles secret storage directly in Infisical.

## See Also

- [Secret Management Documentation](../../../docs/secret-management.md)
- [komodo_auth Role README](../../roles/komodo_auth/README.md)
