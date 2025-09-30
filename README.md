# Ansible Collection - basher83.komodo

Ansible collection for managing Komodo infrastructure and applications.

## Description

This collection provides Ansible roles and playbooks for installing, configuring, and managing Komodo services. It follows Ansible best practices and collection guidelines to ensure maintainability and extensibility.

## Requirements

- Ansible 2.9 or higher
- Python 3.6 or higher

## Installation

### From Ansible Galaxy

```bash
ansible-galaxy collection install basher83.komodo
```

### From Git Repository

```bash
ansible-galaxy collection install git+https://github.com/basher83/hello-komodo.git
```

### Local Development

```bash
git clone https://github.com/basher83/hello-komodo.git
cd hello-komodo
pip install -r requirements.txt
```

## Roles

### komodo

The main role for installing and configuring Komodo.

#### Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `komodo_version` | `latest` | Version of Komodo to install |
| `komodo_user` | `komodo` | System user for Komodo service |
| `komodo_group` | `komodo` | System group for Komodo service |
| `komodo_home` | `/opt/komodo` | Home directory for Komodo |
| `komodo_config_dir` | `/etc/komodo` | Configuration directory |
| `komodo_data_dir` | `/var/lib/komodo` | Data directory |
| `komodo_log_dir` | `/var/log/komodo` | Log directory |
| `komodo_service_enabled` | `true` | Enable Komodo service |
| `komodo_service_state` | `started` | State of Komodo service |
| `komodo_install_method` | `package` | Installation method (package, source, docker) |

#### Example Playbook

```yaml
---
- name: Install and configure Komodo
  hosts: all
  become: true
  collections:
    - basher83.komodo
  roles:
    - komodo
  vars:
    komodo_version: "1.2.3"
    komodo_service_enabled: true
```

## Playbooks

### install.yml

Basic installation playbook that applies the komodo role to all hosts.

```bash
ansible-playbook basher83.komodo.install
```

## Development

### Quick Setup

```bash
# Clone and setup
git clone https://github.com/basher83/hello-komodo.git
cd hello-komodo
chmod +x setup.sh
./setup.sh
```

### Using Make

```bash
# Install dependencies
make install

# Build collection
make build

# Run all linting
make lint

# Run tests
make test

# Clean artifacts
make clean

# Show all targets
make help
```

### Manual Setup

#### Prerequisites

- Python 3.6+
- Ansible 2.9+
- Node.js 16+ (optional, for markdown linting)

#### Install Dependencies

```bash
# Python dependencies
pip install -r requirements.txt

# Node.js dependencies (optional)
npm install
```

### Linting

This collection uses ansible-lint and markdownlint-cli2 for code quality assurance.

```bash
# Run ansible-lint
ansible-lint

# Run YAML lint
yamllint .

# Run markdown lint (requires Node.js)
npm run lint:markdown

# Validate YAML syntax
python3 -c "import yaml; [yaml.safe_load(open(f)) for f in ['ansible_collections/basher83/komodo/galaxy.yml']]"
```

### Testing

```bash
# Build collection
make build

# Install collection locally
ansible-galaxy collection install ./build/basher83-komodo-*.tar.gz --force

# Test playbook syntax
ansible-playbook --syntax-check ansible_collections/basher83/komodo/playbooks/install.yml

# Validate collection structure
ansible-galaxy collection build ansible_collections/basher83/komodo/
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run linting tools
5. Submit a pull request

## License

MIT - See [LICENSE](LICENSE) file for details.

## References

- Based on [ansible-role-komodo](https://github.com/bpbradley/ansible-role-komodo)
- [Ansible Collection Development](https://docs.ansible.com/ansible/latest/dev_guide/developing_collections.html)
- [Ansible Best Practices](https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html)
