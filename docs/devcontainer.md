# Dev Container Configuration

This document explains the development container setup defined in `.devcontainer/devcontainer.json`.

## Base Configuration

### Image

- **Base Image**: `mcr.microsoft.com/devcontainers/python:3.12`
- **Purpose**: Provides Python 3.12 environment with common development tools

## VS Code Customizations

### Extensions

Pre-installed VS Code extensions for development:

- `hverlin.mise-vscode`: Tool version management
- `DavidAnson.vscode-markdownlint`: Markdown linting
- `tamasfe.even-better-toml`: TOML file support
- `GitHub.copilot` & `GitHub.copilot-chat`: AI coding assistance
- `HashiCorp.HCL`: HashiCorp Configuration Language support
- `samuelcolvin.jinjahtml`: Jinja template syntax highlighting
- `SanjulaGanepola.github-local-actions`: GitHub Actions local testing

## Features

### Infisical CLI

- **Feature**: `ghcr.io/skriptfabrik/devcontainer-features/infisical-cli:1`
- **Purpose**: Installs Infisical CLI for secret management

### Tailscale VPN

- **Feature**: `ghcr.io/tailscale/codespace/tailscale`
- **Purpose**: Provides Tailscale VPN connectivity for secure networking
- **Note**: Requires specific Linux capabilities (see runArgs below)

## Storage & Persistence

### Mounts

- **MISE Data Volume**: `source=mise-data-volume,target=/mnt/mise-data,type=volume`
- **Purpose**: Persists MISE tool installations and configurations across container rebuilds

## Post-Creation Setup

### Commands

Executed in sequence after container creation:

1. **MISE Setup** (`.devcontainer/setup-mise.sh`): Configures development environment tools
2. **Tailscale Auth** (`.devcontainer/tailscaled-auth-setup.sh`): Authenticates with Tailscale VPN
3. **Ping Installation** (`sudo apt-get update && sudo apt-get install -y iputils-ping`): Installs network diagnostic tools

## Runtime Arguments

### Linux Capabilities

Required for Tailscale VPN functionality:

- `--device=/dev/net/tun`: Provides TUN device access for VPN tunneling
- `--cap-add=NET_ADMIN`: Allows network interface configuration
- `--cap-add=MKNOD`: Permits creation of device nodes

## Network Configuration

### Tailscale Integration

- **Automatic Mount**: `/var/lib/tailscale` volume for persistent VPN state
- **Kernel Mode**: Uses Linux kernel networking for optimal performance
- **Capabilities**: NET_ADMIN for network management, MKNOD for device creation

## Usage

### Rebuilding Container

When modifying `.devcontainer/devcontainer.json`:

1. Open VS Code Command Palette (`Ctrl+Shift+P`)
2. Run "Dev Containers: Rebuild Container"
3. Wait for rebuild completion

### Troubleshooting

- **Network Issues**: Check Tailscale authentication and capabilities
- **Tool Installation**: Verify MISE configuration in setup scripts
- **Extension Loading**: Restart VS Code if extensions don't load properly

## Related Files

- `.devcontainer/setup-mise.sh`: MISE environment configuration
- `.devcontainer/tailscaled-auth-setup.sh`: Tailscale authentication setup
- `docs/deployment-runbook.md`: Infrastructure deployment procedures
- `docs/developer-tools.md`: Development tool documentation
