# Developer Tools

This document outlines the development tools used in this repository. Each tool is briefly described with links to their official documentation for detailed configuration and usage instructions.

## Environment Management

### Mise

Development environment manager that handles tool version management and project tasks.

- **Purpose**: Unified tool version management and task runner
- **Configuration**: `.mise.toml`, `.mise.local.toml`
- **Tasks**: Formatting, linting, validation, documentation generation
- **Documentation**: [mise.jdx.dev](https://mise.jdx.dev/)

## Quality Assurance & Linting

### Pre-commit

Git hooks framework for running automated checks before commits.

- **Purpose**: Enforce code quality and consistency
- **Configuration**: `.pre-commit-config.yaml`
- **Checks**: Trailing whitespace, YAML validation, executable permissions
- **Documentation**: [pre-commit.com](https://pre-commit.com/)

### Ansible Lint

Lints Ansible playbooks and roles for best practices and common issues.

- **Purpose**: Ensure Ansible code quality and security
- **Configuration**: `.ansible-lint.yml`, `.ansible-lint-ignore`
- **Documentation**: [ansible-lint.readthedocs.io](https://ansible-lint.readthedocs.io/)

### YAML Tools

YAML linting and formatting utilities.

- **yamllint**: Lints YAML files for syntax and style issues
- **yamlfmt**: Formats YAML files consistently
- **Documentation**:
  - yamllint: [yamllint.readthedocs.io](https://yamllint.readthedocs.io/)
  - yamlfmt: [github.com/google/yamlfmt](https://github.com/google/yamlfmt)

### ShellCheck

Static analysis tool for shell scripts.

- **Purpose**: Find bugs and potential issues in shell scripts
- **Configuration**: Integrated with mise task runner
- **Documentation**: [shellcheck.net](https://shellcheck.net/)

### MarkdownLint

Markdown file linting for consistency and readability.

- **Purpose**: Ensure consistent Markdown formatting across documentation
- **Configuration**: Integrated with mise task runner
- **Documentation**: [github.com/DavidAnson/markdownlint](https://github.com/DavidAnson/markdownlint)

## Documentation

### Git Cliff

Changelog generation from conventional commits.

- **Purpose**: Generate structured changelogs from git history
- **Configuration**: `cliff.toml`
- **Output**: `CHANGELOG.md`
- **Documentation**: [git-cliff.org](https://git-cliff.org/)

## Automation & CI/CD

### GitHub Actions

Workflow automation for CI/CD pipelines.

- **Purpose**: Automated testing, validation, and deployment
- **Workflows**: `.github/workflows/`
  - `documentation.yml`: Documentation validation
  - `use-sync-labels.yml`: Label synchronization
- **Documentation**: [docs.github.com/actions](https://docs.github.com/actions)

### Renovate

Automated dependency updates for infrastructure tools and packages.

- **Purpose**: Keep dependencies up-to-date with automated PRs
- **Configuration**: `renovate.json`
- **Documentation**: [docs.renovatebot.com](https://docs.renovatebot.com/)

## Security & Secrets

### Infisical

Secret management and scanning for sensitive data.

- **Purpose**: Secure secret handling and leak prevention
- **Configuration**: `.infisical.json`
- **Features**: Secret scanning, pre-commit hooks
- **Documentation**: [infisical.com/docs](https://infisical.com/docs)

## Additional Utilities

### fd & ripgrep

Enhanced file finding and text searching utilities.

- **fd**: Modern `find` replacement with sensible defaults
- **ripgrep**: Fast text search tool (used in various scripts)
- **Documentation**:
  - fd: [sharkdp.github.io/fd](https://sharkdp.github.io/fd/)
  - ripgrep: [github.com/BurntSushi/ripgrep](https://github.com/BurntSushi/ripgrep)
