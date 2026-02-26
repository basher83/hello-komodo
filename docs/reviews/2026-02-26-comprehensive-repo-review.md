# Comprehensive Repository Review

**Repository:** hello-komodo (Ansible/Komodo Infrastructure)
**Date:** 2026-02-26
**Review Scope:** Security, Code Quality, Functionality Gaps, Code Simplification

---

## Executive Summary

This Ansible repository manages a Komodo hub-and-spoke container orchestration
platform with Komodo Core as the central controller and Periphery agents on
distributed nodes connected via Tailscale VPN. The codebase demonstrates solid
architectural thinking with its pluggable secret backend system, ordered
playbook deployment, and reusable shared tasks.

However, four parallel deep-dive reviews uncovered **significant findings** that
should be addressed to improve security posture, operational resilience, and
maintainability. The single most impactful cross-cutting issue is the
**incomplete migration from 1Password to Infisical** -- the `compose.env.j2`
template and `05_app_syncs.yml` still hardcode 1Password lookups while the rest
of the system defaults to Infisical, creating a broken deployment path for
anyone using the default backend.

### Finding Summary by Area

| Review Area        | Critical | High | Medium | Low | Info |
|--------------------|----------|------|--------|-----|------|
| Security           | 0        | 7    | 11     | 5   | 5    |
| Code Quality       | 0        | 7    | 12     | 8   | 0    |
| Functionality Gaps | --       | 13   | 14     | 8   | --   |
| Simplification     | --       | 2    | 12     | 11  | --   |

### Top 5 Priority Actions

1. **Fix compose.env.j2 secret backend inconsistency** -- Prevents deployment
   failures for Infisical users
2. **Restrict compose.env file permissions to 0600** -- Secrets currently
   world-readable
3. **Pin container images and role versions** -- Supply chain risk from floating
   `latest` tags
4. **Add CI pipeline for PR validation** -- No automated linting/testing exists
5. **Implement MongoDB backup strategy** -- No backup mechanism for critical
   data

---

## 1. Security Review

### 1.1 Secret Management & Credential Exposure

#### SEC-01: Compose Environment File World-Readable (HIGH)

- **File:** `ansible/roles/komodo/tasks/main.yml:18-21`
- **Issue:** The `compose.env` file is deployed with `mode: "0644"`, making it
  readable by all users on the system. This file contains rendered secrets
  including database credentials, the core-to-periphery passkey, JWT secret,
  webhook secret, OIDC client secret, and database passwords.
- **Fix:** Change to `mode: "0600"` with owner set to root or the Docker
  runtime user.

#### SEC-02: Secret Backend Mismatch -- 1Password Hardcoded in Templates (HIGH)

- **File:** `ansible/roles/komodo/templates/compose.env.j2:22-88`
- **Cross-ref:** `ansible/inventory/all.yml:46-57`
- **Issue:** The inventory configures credentials using Infisical lookups and
  the default backend is `infisical`, but `compose.env.j2` exclusively uses
  `community.general.onepassword` lookups for ALL secrets. The core deployment
  will fail unless 1Password CLI (`op`) is authenticated, regardless of the
  configured secret backend.
- **Fix:** Refactor `compose.env.j2` to use backend-agnostic variables defined
  in inventory. Replace inline 1Password lookups with Ansible variables (e.g.,
  `{{ komodo_db_username }}` instead of `lookup('community.general.onepassword',
  ...)`).

#### SEC-03: Infisical Project ID Hardcoded in 6+ Locations (MEDIUM)

- **Files:** `ansible/inventory/all.yml`, `ansible/roles/komodo_auth/defaults/main.yml:25`,
  `ansible/tasks/infisical-secret-lookup.yml:55`,
  `ansible/playbooks/infisical-patterns.yml:15,41,54`, `.mise.toml:57-58`
- **Issue:** The Infisical project ID `7b832220-24c0-45bc-a5f1-ce9794a31259` is
  hardcoded in at least 6 files. Changing it requires updates across all files.
- **Fix:** Define once as `infisical_project_id` in inventory and reference
  everywhere.

#### SEC-04: Duplicate KOMODO_WEBHOOK_SECRET in Template (LOW)

- **File:** `ansible/roles/komodo/templates/compose.env.j2:60,114`
- **Issue:** `KOMODO_WEBHOOK_SECRET` is defined twice with identical values.
- **Fix:** Remove the duplicate at line 114.

#### SEC-05: Test Playbooks Display Secrets in Output (MEDIUM)

- **Files:** `ansible/playbooks/infisical-test.yml:33-49`,
  `ansible/playbooks/infisical-patterns.yml:78-95`
- **Issue:** Test playbooks write secrets to `/tmp/komodo.env`, cat the file,
  and display contents via `debug` without `no_log: true` on the display tasks.
- **Fix:** Add `no_log: true` to display tasks, or verify only secret length.

#### SEC-06: .gitignore Missing Common Secret File Patterns (MEDIUM)

- **File:** `.gitignore`
- **Issue:** Does not exclude `.env`, `compose.env`, `*vault*`, `*.pem`,
  `*.key`, or `credentials.json` files.
- **Fix:** Add comprehensive secret file exclusions.

#### SEC-07: Legacy store_credentials.yml Is Dead Code (LOW)

- **File:** `ansible/roles/komodo_auth/tasks/store_credentials.yml`
- **Issue:** Passes secrets as command-line arguments via `ansible.builtin.shell`
  to `op item edit`. Superseded by `backends/1password.yml` and
  `backends/infisical.yml`. Dead code handling secrets increases audit surface.
- **Fix:** Remove the file.

### 1.2 Network Security

#### SEC-08: SSH Host Key Checking Completely Disabled (HIGH)

- **File:** `ansible/ansible.cfg:5,18`
- **Issue:** Both `host_key_checking = False` and
  `StrictHostKeyChecking=no` with `UserKnownHostsFile=/dev/null` are
  configured, making ALL SSH connections vulnerable to MITM attacks.
- **Fix:** Use a maintained `known_hosts` file for Tailscale hosts.
  Document risk acceptance if intentional.

#### SEC-09: All Komodo Core API Communication Over HTTP (HIGH)

- **File:** `ansible/inventory/all.yml:31`
- **Issue:** `komodo_core_url` uses `http://` (not HTTPS). All API calls
  transmitting admin credentials, JWT tokens, API keys, and secrets are sent
  in plaintext.
- **Fix:** Configure Komodo Core with TLS/HTTPS or add a reverse proxy.

#### SEC-10: MongoDB Port Exposed on Host Network (MEDIUM)

- **File:** `ansible/roles/komodo/templates/komodo-compose.yml.j2:17-18`
- **Issue:** MongoDB is published as `{{ komodo_mongo_port }}:27017` on the
  host. Any Tailscale peer can attempt to connect.
- **Fix:** Remove the host port mapping; Core connects via Docker internal
  network. If needed, bind to `127.0.0.1:27017:27017`.

#### SEC-11: Periphery Binds to 0.0.0.0 with Empty Allowed IPs (MEDIUM)

- **Files:** `ansible/inventory/all.yml:23,25`
- **Issue:** Periphery listens on all interfaces with no IP restrictions
  (`komodo_allowed_ips: []`).
- **Fix:** Bind to Tailscale interface only or populate
  `komodo_allowed_ips` with Core's IP.

#### SEC-12: SSH Control Path in World-Readable /tmp (LOW)

- **File:** `ansible/ansible.cfg:20`
- **Issue:** SSH control sockets placed in `/tmp` expose connection info.
- **Fix:** Use `~/.ansible/cp/%%h-%%p-%%r`.

### 1.3 Container Security

#### SEC-13: MongoDB Image Uses Unpinned Tag (HIGH)

- **File:** `ansible/roles/komodo/templates/komodo-compose.yml.j2:12`
- **Issue:** `image: mongo` uses unpinned `latest` tag. Supply chain attack
  risk and potential breaking changes on every pull.
- **Fix:** Pin to specific version with SHA256 digest:
  `image: mongo:7.0@sha256:<hash>`.

#### SEC-14: Core and Periphery Default to `latest` Tags (MEDIUM)

- **Files:** `ansible/roles/komodo/templates/compose.env.j2:15`,
  `ansible/inventory/all.yml:20`
- **Issue:** Both Core image tag and Periphery version default to `latest`,
  making deployments non-reproducible.
- **Fix:** Pin to specific version tags.

#### SEC-15: No Container Security Hardening (MEDIUM)

- **File:** `ansible/roles/komodo/templates/komodo-compose.yml.j2`
- **Issue:** No `read_only`, `no-new-privileges`, `cap_drop: [ALL]`,
  memory/CPU limits, or user namespace remapping on any container.
- **Fix:** Add security hardening options to compose template.

### 1.4 Authentication & Authorization

#### SEC-16: API Keys Created with No Expiration (HIGH)

- **File:** `ansible/roles/komodo_auth/tasks/create_api_key.yml:15`
- **Issue:** `expires: 0` (never expires). No rotation mechanism exists.
- **Fix:** Set reasonable expiration and implement rotation playbook.

#### SEC-17: Service User Has Full Admin Permissions (MEDIUM)

- **File:** `ansible/roles/komodo_auth/tasks/manage_service_user.yml:44-58`
- **Issue:** Automation service user granted `admin: true` instead of granular
  permissions.
- **Fix:** Grant only specific permissions needed for automation tasks.

#### SEC-18: API Key/Secret Not Protected with no_log at Creation (MEDIUM)

- **File:** `ansible/roles/komodo_auth/tasks/create_api_key.yml:3-16`
- **Issue:** The `uri` task creating the API key lacks `no_log: true`.
  Response containing key and secret visible in verbose output.
- **Fix:** Add `no_log: true` to the URI task.

#### SEC-19: Broad Error Status Acceptance (500) on Service User Creation (LOW)

- **File:** `ansible/roles/komodo_auth/tasks/manage_service_user.yml:15`
- **Issue:** `status_code: [200, 201, 409, 500]` silently accepts server
  errors.
- **Fix:** Check response body for "already exists" rather than
  blanket-accepting 500s.

### 1.5 Supply Chain & Dependencies

#### SEC-20: bpbradley.komodo Role Not Version-Pinned (MEDIUM)

- **File:** `ansible/requirements.yml:12`
- **Issue:** No version pin on external role. `geerlingguy.docker` is
  properly pinned to `7.9.0`, but `bpbradley.komodo` could introduce
  breaking changes silently.
- **Fix:** Pin to specific version.

### 1.6 Positive Security Findings (INFO)

- **Tailscale auth key handling** in `.devcontainer/tailscaled-auth-setup.sh`
  properly unsets the key from exported environment
- **GitHub workflow** uses pinned SHA commit reference with properly scoped
  permissions
- **Pre-commit hooks** include `detect-private-key`, `detect-aws-credentials`,
  and Infisical secret scanning
- **Dynamic inventory script** uses `subprocess.run()` safely (no `shell=True`)
- **No overly permissive file modes** (0777/0666) found in custom code

---

## 2. Code Quality Review

### 2.1 Ansible Best Practices

#### CQ-01: import_playbook with `when` Conditional Anti-Pattern (HIGH)

- **File:** `ansible/site.yml:22-30`
- **Issue:** `when` applied to `import_playbook` is a known anti-pattern.
  `import_playbook` is a static import at parse time; the `when` condition gets
  pushed to every task inside the imported playbook rather than conditionally
  skipping the import. Tasks still get parsed and appear as skipped in output.
- **Fix:** Move conditional logic inside the imported playbooks, or restructure
  to use conditional `include_tasks`.

#### CQ-02: Docker Installation Marker File Prevents Upgrades (MEDIUM)

- **File:** `ansible/playbooks/01_docker.yml:8-15,43-47`
- **Issue:** Creates `/opt/.docker_install_complete` marker and uses
  `meta: end_host` to skip nodes. Docker can never be upgraded or reconfigured
  via this playbook. The `geerlingguy.docker` role is itself idempotent.
- **Fix:** Remove marker file mechanism; rely on role idempotency.

#### CQ-03: Commented-Out Variables Create Runtime Failure Risk (HIGH)

- **File:** `ansible/inventory/all.yml:80,84-86`
- **Issue:** `enable_komodo_op`, `komodo_resource_syncs_repo`,
  `komodo_resource_syncs_branch`, `komodo_resource_syncs_git_account` are
  commented out but referenced without defaults in `06_deploy_komodo_op.yml`.
  Enabling `enable_komodo_op` without uncommenting these causes undefined
  variable errors.
- **Fix:** Set defaults using `| default(...)` filters or add assertion blocks
  with clear error messages.

#### CQ-04: Stack Operations Checks Wrong Array Index (HIGH)

- **File:** `ansible/tasks/komodo_stack_operations.yml:92`
- **Issue:** "Wait for stack services" checks `stack_services.json[0].info.state`,
  always checking the first stack regardless of which is being monitored.
- **Fix:** Filter stack list by stack name before checking state.

#### CQ-05: Handler Uses Undefined ansible_env Variable (MEDIUM)

- **File:** `ansible/roles/komodo/handlers/main.yml:10`
- **Issue:** `environment: "{{ ansible_env }}"` requires `gather_facts: true`
  and passes the entire process environment to Docker Compose, potentially
  leaking variables.
- **Fix:** Remove the `environment` line or pass specific variables explicitly.

#### CQ-06: Missing no_log on JWT Token Usage (MEDIUM)

- **File:** `ansible/roles/komodo_auth/tasks/manage_service_user.yml:1-59`
- **Issue:** No tasks use `no_log: true` despite including JWT tokens in
  Authorization headers. Tokens visible in verbose output.
- **Fix:** Add `no_log: true` to all URI tasks with JWT headers.

#### CQ-07: Unused Variables in komodo Role Defaults (LOW)

- **File:** `ansible/roles/komodo/defaults/main.yml:8-10`
- **Issue:** `komodo_health_check_retries`, `komodo_health_check_delay`,
  `komodo_systemd_service_enabled` defined but never referenced. Tasks use
  hardcoded values instead.
- **Fix:** Use variables in tasks or remove from defaults.

### 2.2 Configuration & Consistency

#### CQ-08: 05_app_syncs.yml Uses Different Secret Backend (HIGH)

- **File:** `ansible/playbooks/05_app_syncs.yml:12-13`
- **Issue:** Hardcodes 1Password lookups while optional playbooks correctly use
  centralized `komodo_core_api_key` / `komodo_core_api_secret` variables.
- **Fix:** Replace with centralized variables.

#### CQ-09: ansible.cfg Inventory Path Does Not Match Reality (MEDIUM)

- **File:** `ansible/ansible.cfg:2`
- **Issue:** Config sets `inventory = inventory` but actual inventory is
  `all.yml`. Documentation references non-existent `hosts.yml`.
- **Fix:** Change to `inventory = inventory/all.yml` and update docs.

#### CQ-10: Fragile Relative Path for Infisical Backend Includes (MEDIUM)

- **File:** `ansible/roles/komodo_auth/tasks/backends/infisical.yml:13,78`
- **Issue:** Uses `{{ playbook_dir }}/../../../../tasks/infisical-secret-lookup.yml`.
  Breaks if role is moved or used from different playbook location.
- **Fix:** Use `{{ role_path }}` or define shared tasks path variable.

#### CQ-11: mise-tasks/ansible/install Runs from Wrong Directory (MEDIUM)

- **File:** `mise-tasks/ansible/install:5-8`
- **Issue:** Checks for `requirements.yml` in current directory but doesn't
  change to `ansible/` directory first. TOML task correctly sets
  `dir = "ansible"` but file-based task does not.
- **Fix:** Add `cd ansible` or reference `ansible/requirements.yml`.

### 2.3 Documentation Issues

#### CQ-12: ansible/README.md References Non-Existent Makefile (MEDIUM)

- **File:** `ansible/README.md:30,73-124,242,351`
- **Issue:** Extensively documents `make` targets and references
  `scripts/setup-ansible.sh`, but no Makefile or scripts directory exists.
- **Fix:** Rewrite to use `mise run` tasks and `ansible-playbook` commands.

#### CQ-13: deployment-runbook.md References Incorrect Playbook Paths (LOW)

- **File:** `docs/deployment-runbook.md:127-134,258-265`
- **Issue:** References `playbooks/05_bootstrap_komodo_op.yml` (should be
  `playbooks/optional/05_bootstrap_komodo_op.yml`) and
  `playbooks/07_app_syncs.yml` (should be `playbooks/05_app_syncs.yml`).
- **Fix:** Update paths to match actual locations.

#### CQ-14: CLAUDE.md Version Numbers Are Stale (LOW)

- **File:** `CLAUDE.md:171-173`
- **Issue:** States "ansible-core 2.19.1" and "python 3.13.7" but `.mise.toml`
  specifies `python = "3.14.2"` and lock file shows `ansible-core==2.19.2`.
- **Fix:** Reference `.mise.toml` as source of truth instead of listing
  versions.

#### CQ-15: ansible/README.md Says Ansible 2.9+ but Code Requires 2.12+ (LOW)

- **File:** `ansible/README.md:19`
- **Issue:** States "Ansible 2.9+" but `komodo_auth/meta/main.yml` requires
  2.12+ and `community.docker.docker_compose_v2` needs newer.
- **Fix:** Update to actual minimum version.

---

## 3. Functionality Gap Analysis

### 3.1 Monitoring & Observability

#### FG-01: No Log Aggregation (HIGH)

- **Description:** Docker containers use `local` logging driver with no
  aggregation. Diagnosing issues requires SSH-ing into individual machines.
  The `komodo_logging_otlp_endpoint` variable exists in the bpbradley.komodo
  role but is unused.
- **Recommendation:** Deploy Loki + Promtail/Alloy for centralized logging.
  Create `ansible/roles/logging/` and optional playbook.
- **Complexity:** COMPLEX

#### FG-02: No Metrics Collection or Dashboards (HIGH)

- **Description:** No system or application metrics collected. Core polls
  servers at 15s intervals but doesn't export to external monitoring.
- **Recommendation:** Deploy node-exporter, cAdvisor, Prometheus/VictoriaMetrics,
  and Grafana. Wire up existing OTLP endpoint.
- **Complexity:** COMPLEX

#### FG-03: No Alerting System (MEDIUM)

- **Description:** No automated notifications for service crashes, disk
  issues, or node failures. Status playbook must be run manually.
- **Recommendation:** Add Alertmanager or Grafana alerting with notification
  channels.
- **Complexity:** MODERATE

#### FG-04: Health Checks Are Minimal (MEDIUM)

- **Description:** Current health check is a single HTTP GET. No checks for
  MongoDB health, disk space, Docker daemon, Periphery connectivity, or
  certificate validity.
- **Recommendation:** Expand health checks to cover all critical components.
- **Complexity:** MODERATE

### 3.2 Backup & Disaster Recovery

#### FG-05: No MongoDB Backup Mechanism (HIGH)

- **Description:** MongoDB stores all Komodo state in Docker volumes with no
  backup. Failed disk or accidental deletion means complete data loss.
- **Recommendation:** Create backup playbook using `mongodump` with scheduled
  execution and retention policies. Add optional remote upload (S3/B2).
- **Complexity:** MODERATE

#### FG-06: No Disaster Recovery / Restore Procedure (HIGH)

- **Description:** No documented or automated restore procedure. Full
  reconstruction from backup requires manual intervention.
- **Recommendation:** Create restore playbook and DR documentation.
- **Complexity:** COMPLEX

#### FG-07: No Configuration Backup/Export (MEDIUM)

- **Description:** No mechanism to back up running state: compose.env with
  rendered secrets, Komodo API configuration, resource syncs, or variables.
- **Recommendation:** Create config export playbook using Komodo API.
- **Complexity:** MODERATE

### 3.3 Deployment & Operations

#### FG-08: No Rollback Procedure (HIGH)

- **Description:** Forward-only deployments with `latest` tags. No way to
  revert a failed upgrade. Previous versions not tracked.
- **Recommendation:** Add `komodo_version` variable, record current version
  before deploy, create rollback playbook.
- **Complexity:** MODERATE

#### FG-09: Version Pinning Not Implemented (HIGH)

- **Description:** Core uses `latest` image tag, Periphery defaults to
  `latest`. Deployments are non-reproducible.
- **Recommendation:** Pin versions in inventory. Add version matrix for
  Core/Periphery compatibility.
- **Complexity:** SIMPLE

#### FG-10: No Pre-deployment Validation (MEDIUM)

- **Description:** No pre-flight checks before deployment for disk space,
  port availability, network connectivity, or secret backend availability.
- **Recommendation:** Create `00_preflight.yml` validation playbook.
- **Complexity:** MODERATE

#### FG-11: No Maintenance Mode (MEDIUM)

- **Description:** No way to put infrastructure into maintenance during
  upgrades. Users can trigger deployments during maintenance windows.
- **Recommendation:** Create maintenance mode playbook using compose
  overrides.
- **Complexity:** MODERATE

### 3.4 Testing & Validation

#### FG-12: No Molecule Tests for Custom Roles (HIGH)

- **Description:** `komodo` and `komodo_auth` roles have no test suites.
  Changes cannot be validated without deploying to production.
- **Recommendation:** Add Molecule test scenarios for both roles with Docker
  driver.
- **Complexity:** COMPLEX

#### FG-13: No Post-Deployment Smoke Tests (HIGH)

- **Description:** No automated end-to-end verification after deployment.
  No test that API auth works, Periphery nodes are registered, or syncs
  are healthy.
- **Recommendation:** Create `smoke_tests.yml` playbook.
- **Complexity:** MODERATE

#### FG-14: No CI Pipeline (HIGH)

- **Description:** Only GitHub Action is label sync. No CI for linting,
  testing, or validation on PRs. Pre-commit hooks are local-only.
- **Recommendation:** Create `.github/workflows/ci.yml` with yamllint,
  ansible-lint, syntax-check, and Infisical scan.
- **Complexity:** MODERATE

#### FG-15: ansible-lint Profile Is Minimal (MEDIUM)

- **File:** `ansible/.ansible-lint:2`
- **Description:** Profile set to `safety` (lowest). Higher profiles would
  catch more best-practice violations.
- **Recommendation:** Incrementally upgrade to `moderate` then `production`.
- **Complexity:** SIMPLE

### 3.5 Multi-Environment & Scaling

#### FG-16: No Multi-Environment Support (HIGH)

- **Description:** Single inventory for production only. No dev/staging/prod
  separation. Testing requires manual inventory editing.
- **Recommendation:** Restructure to `inventory/production/`,
  `inventory/staging/` with environment-specific group_vars.
- **Complexity:** MODERATE

#### FG-17: Dynamic Inventory Not Integrated (MEDIUM)

- **Description:** Tailscale dynamic inventory script exists but is unused.
  Static inventory hardcodes hosts.
- **Recommendation:** Integrate with Tailscale ACL tags for automatic host
  classification.
- **Complexity:** MODERATE

### 3.6 TLS & Certificate Management

#### FG-18: No TLS for Komodo Core (HIGH)

- **Description:** Core exposed on plain HTTP (port 9120). No reverse proxy.
  All traffic including credentials is unencrypted.
- **Recommendation:** Add Caddy reverse proxy with automatic HTTPS to compose
  stack.
- **Complexity:** MODERATE

#### FG-19: Periphery Uses Self-Signed Certificates (MEDIUM)

- **Description:** SSL enabled but cert paths empty. Self-signed certs
  prevent proper TLS verification between Core and Periphery.
- **Recommendation:** Deploy proper certificates via Tailscale TLS, private
  CA, or Let's Encrypt with DNS challenge.
- **Complexity:** COMPLEX

### 3.7 User & Access Management

#### FG-20: No API Key Rotation (HIGH)

- **Description:** Keys never expire (`expires: 0`), no rotation mechanism.
  Only option is `komodo_auth_force_recreate=true` which recreates everything.
- **Recommendation:** Create rotation playbook with configurable TTL.
- **Complexity:** MODERATE

#### FG-21: No Multi-User Management (MEDIUM)

- **Description:** Only one admin + one service user supported. No playbook
  for managing additional users, roles, or permissions.
- **Recommendation:** Extend `komodo_auth` role with user list configuration.
- **Complexity:** MODERATE

### 3.8 CI/CD & Infrastructure

#### FG-22: No Infrastructure Drift Detection (MEDIUM)

- **Description:** No way to detect if running infrastructure has drifted from
  desired state. Manual server changes go unnoticed.
- **Recommendation:** Schedule `site.yml --check --diff` in CI and report
  differences.
- **Complexity:** MODERATE

#### FG-23: No Firewall Management (HIGH)

- **Description:** No firewall rules managed by any playbook. All ports
  implicitly open on all hosts.
- **Recommendation:** Create firewall role using ufw. Define allowed ports
  per host group.
- **Complexity:** MODERATE

#### FG-24: Ansible Vault Backend Not Implemented (MEDIUM)

- **File:** `ansible/roles/komodo_auth/defaults/main.yml:17`
- **Description:** `ansible_vault` listed as supported backend but no
  `backends/ansible_vault.yml` exists. Selecting it causes file-not-found
  error.
- **Recommendation:** Create implementation or remove from supported list.
- **Complexity:** MODERATE

#### FG-25: No Docker Resource Limits (MEDIUM)

- **Description:** No memory/CPU limits on MongoDB or Core containers. A
  runaway process can consume all host resources.
- **Recommendation:** Add `deploy.resources.limits` to compose template with
  configurable defaults.
- **Complexity:** SIMPLE

---

## 4. Code Simplification Review

### 4.1 Redundancy & Duplication

#### CS-01: Dead store_credentials.yml File (MEDIUM)

- **File:** `ansible/roles/komodo_auth/tasks/store_credentials.yml`
- **Current:** Duplicates 1Password operations from `backends/1password.yml`.
  Never referenced from `main.yml`.
- **Action:** Delete the file.
- **Risk:** LOW

#### CS-02: Duplicate Infisical Test Playbooks (MEDIUM)

- **Files:** `ansible/playbooks/infisical-test.yml`,
  `ansible/playbooks/infisical-patterns.yml`
- **Current:** Contain overlapping test logic with repeated
  write/cat/cleanup patterns.
- **Action:** Consolidate into single test playbook.
- **Risk:** LOW

#### CS-03: Repeated Komodo API Headers (15+ Occurrences) (MEDIUM)

- **Files:** `komodo_variable_operations.yml`, `komodo_stack_operations.yml`,
  `komodo_sync_operations.yml`, `05_bootstrap_komodo_op.yml`,
  `06_deploy_komodo_op.yml`, `05_app_syncs.yml`
- **Current:** Headers block (`X-Api-Key`, `X-Api-Secret`, `Content-Type`)
  copy-pasted across all API calls.
- **Action:** Define `komodo_api_headers` variable once, reference
  throughout.
- **Risk:** LOW

#### CS-04: Repeated komodo_base_url Definitions (MEDIUM)

- **Current:** Multiple playbooks redundantly define `komodo_port`,
  `komodo_base_url`, `komodo_api_key`, `komodo_api_secret`. Inventory already
  defines `komodo_core_url`.
- **Action:** Use `komodo_core_url` from inventory consistently.
- **Risk:** LOW

#### CS-05: Duplicated Docker Check Pre-Tasks (LOW)

- **Files:** `ansible/playbooks/02_komodo_core.yml`,
  `ansible/playbooks/04_komodo_periphery.yml`
- **Current:** Identical Docker installation verification block.
- **Action:** Extract to shared task file.
- **Risk:** LOW

### 4.2 Over-Engineering

#### CS-06: Verbose Infisical Lookups in Inventory (HIGH)

- **File:** `ansible/inventory/all.yml`
- **Current:** Each secret lookup repeats 40+ character boilerplate
  (`universal_auth_client_id`, `universal_auth_client_secret`, `project_id`,
  `env_slug`, `path`). Lines are 160+ characters. Same params repeated 4 times.
- **Action:** Extract shared lookup parameters as variables. Use
  `as_dict=True` pattern (already demonstrated in `infisical-patterns.yml`)
  to fetch all secrets in a single call.
- **Risk:** MEDIUM

#### CS-07: compose.env.j2 Hardcodes 1Password Instead of Variables (HIGH)

- **File:** `ansible/roles/komodo/templates/compose.env.j2`
- **Current:** ~10 hardcoded 1Password lookups. Rest of project migrated to
  Infisical. Template cannot work without 1Password.
- **Action:** Replace all 1Password lookups with backend-agnostic Ansible
  variables defined in inventory.
- **Risk:** MEDIUM

#### CS-08: Unused Single-Variable Task and Fragile json[0] (LOW)

- **File:** `ansible/tasks/komodo_stack_operations.yml`
- **Current:** Single-variable creation task unused (batch handles
  single-element lists). Wait task checks wrong array index.
- **Action:** Remove unused tasks, fix wait logic.
- **Risk:** LOW

#### CS-09: Unused Dynamic Tailscale Inventory Script (LOW)

- **File:** `ansible/inventory/dynamic_tailscale.py`
- **Current:** 259-line script never referenced by any playbook or config.
- **Action:** Either integrate or move to `contrib/` directory.
- **Risk:** LOW

#### CS-10: Unused Role Defaults (LOW)

- **File:** `ansible/roles/komodo/defaults/main.yml`
- **Current:** `komodo_health_check_retries`, `komodo_health_check_delay`,
  `komodo_compose_service_name`, `komodo_systemd_service_enabled` defined
  but never used (hardcoded values used instead).
- **Action:** Use variables in tasks or remove from defaults.
- **Risk:** LOW

### 4.3 Configuration & Tooling

#### CS-11: Duplicate .yamllint Configuration Files (MEDIUM)

- **Files:** `.yamllint`, `ansible/.yamllint`
- **Current:** Two identical 29-line files. Changes must be made in both.
- **Action:** Keep only root `.yamllint`, remove `ansible/.yamllint`.
- **Risk:** LOW

#### CS-12: Duplicate Mise Task Systems (MEDIUM)

- **Files:** `.mise.toml`, `mise-tasks/*`
- **Current:** File-based tasks in `mise-tasks/` and TOML-based tasks in
  `.mise.toml` coexist. `ansible/install` (file) and `ansible-setup` (TOML)
  do different things with similar names.
- **Action:** Consolidate all tasks into single system (TOML).
- **Risk:** LOW

#### CS-13: Mismatched yamllint Versions (LOW)

- **Files:** `.pre-commit-config.yaml` (`v1.35.1`), `.mise.toml` (`1.38.0`),
  `requirements.lock` (`1.37.1`)
- **Action:** Align versions across all configuration files.
- **Risk:** LOW

#### CS-14: Commented-Out OAuth Blocks in Template (LOW)

- **File:** `ansible/roles/komodo/templates/compose.env.j2:96-103`
- **Current:** GitHub OAuth and Google OAuth blocks commented out, adding noise.
- **Action:** Remove or move to documentation.
- **Risk:** LOW

### 4.4 Documentation

#### CS-15: Duplicate Mise Task Documentation Files (MEDIUM)

- **Files:** `docs/mise-tasks-inject.md`, `docs/mise-tasks-simple.md`
- **Current:** Identical content (11 tasks). Only difference is `-i` flag in
  generation command.
- **Action:** Keep one, delete the other.
- **Risk:** LOW

#### CS-16: Significant Documentation Overlap Across 6+ Files (MEDIUM)

- **Files:** `README.md`, `CLAUDE.md`, `ansible/README.md`,
  `docs/deployment-runbook.md`, `docs/secret-management.md`,
  `ansible/roles/komodo_auth/README.md`
- **Current:** Same information repeated with inconsistencies (tool versions,
  non-existent Makefile references, playbook numbering).
- **Action:** Establish documentation hierarchy with cross-references instead
  of duplication. `README.md` for overview, `CLAUDE.md` for AI guidance only,
  `docs/` for detailed topics.
- **Risk:** LOW

### 4.5 Inventory

#### CS-17: Inventory File Mixes Concerns (MEDIUM)

- **File:** `ansible/inventory/all.yml`
- **Current:** 117-line file mixes infrastructure constants, secret lookups,
  commented-out alternative configurations, and host definitions.
- **Action:** Remove commented alternatives (already in docs). Consider
  `group_vars/all.yml` for variables, reserve inventory for hosts/groups.
- **Risk:** MEDIUM

---

## 5. Recommended Implementation Roadmap

### Phase 1: Critical Fixes (Immediate)

These items address security vulnerabilities and broken functionality:

| # | Item | Findings | Effort |
|---|------|----------|--------|
| 1 | Fix compose.env.j2 secret backend inconsistency | SEC-02, CQ-08, CS-07 | MODERATE |
| 2 | Restrict compose.env file permissions to 0600 | SEC-01 | SIMPLE |
| 3 | Pin MongoDB image to specific version | SEC-13, CQ-16 | SIMPLE |
| 4 | Pin Core/Periphery versions in inventory | SEC-14, FG-09 | SIMPLE |
| 5 | Pin bpbradley.komodo role version | SEC-20 | SIMPLE |
| 6 | Fix stack operations wrong array index | CQ-04 | SIMPLE |
| 7 | Remove dead store_credentials.yml | SEC-07, CS-01 | SIMPLE |
| 8 | Remove duplicate KOMODO_WEBHOOK_SECRET | SEC-04, CS-14 | SIMPLE |

### Phase 2: Security Hardening (1-2 Weeks)

| # | Item | Findings | Effort |
|---|------|----------|--------|
| 9 | Add TLS reverse proxy for Komodo Core | SEC-09, FG-18 | MODERATE |
| 10 | Remove MongoDB external port mapping | SEC-10 | SIMPLE |
| 11 | Restrict Periphery binding / populate allowed_ips | SEC-11 | SIMPLE |
| 12 | Add no_log to sensitive API tasks | SEC-18, CQ-06 | SIMPLE |
| 13 | Set API key expiration and create rotation playbook | SEC-16, FG-20 | MODERATE |
| 14 | Add comprehensive .gitignore patterns | SEC-06 | SIMPLE |
| 15 | Create firewall management role/playbook | FG-23 | MODERATE |
| 16 | Add container security hardening to compose template | SEC-15 | SIMPLE |

### Phase 3: Code Quality & Simplification (2-4 Weeks)

| # | Item | Findings | Effort |
|---|------|----------|--------|
| 17 | Centralize Infisical project ID | SEC-03, CQ-08, CS-06 | SIMPLE |
| 18 | Consolidate API headers into reusable variable | CS-03 | SIMPLE |
| 19 | Consolidate duplicate test playbooks | CS-02 | SIMPLE |
| 20 | Fix import_playbook with when anti-pattern | CQ-01 | MODERATE |
| 21 | Remove Docker installation marker mechanism | CQ-02 | SIMPLE |
| 22 | Consolidate .yamllint files | CS-11 | SIMPLE |
| 23 | Unify mise task systems | CS-12 | MODERATE |
| 24 | Update all documentation to match reality | CQ-12-15, CS-15-16 | MODERATE |

### Phase 4: Operational Maturity (1-3 Months)

| # | Item | Findings | Effort |
|---|------|----------|--------|
| 25 | Create CI pipeline for PR validation | FG-14 | MODERATE |
| 26 | Implement MongoDB backup playbook | FG-05 | MODERATE |
| 27 | Create post-deployment smoke tests | FG-13 | MODERATE |
| 28 | Add pre-deployment validation playbook | FG-10 | MODERATE |
| 29 | Implement multi-environment inventory | FG-16 | MODERATE |
| 30 | Create rollback procedure | FG-08 | MODERATE |
| 31 | Add Molecule tests for custom roles | FG-12 | COMPLEX |

### Phase 5: Advanced Operations (3-6 Months)

| # | Item | Findings | Effort |
|---|------|----------|--------|
| 32 | Deploy log aggregation (Loki + Promtail) | FG-01 | COMPLEX |
| 33 | Deploy metrics collection (Prometheus + Grafana) | FG-02 | COMPLEX |
| 34 | Create disaster recovery playbook | FG-06 | COMPLEX |
| 35 | Implement alerting system | FG-03 | MODERATE |
| 36 | Add Periphery TLS certificate management | FG-19 | COMPLEX |
| 37 | Implement infrastructure drift detection | FG-22 | MODERATE |
| 38 | Create automated deployment pipeline | FG-22 | COMPLEX |

---

## Appendix A: Files Most Frequently Cited

| File | Finding Count | Areas |
|------|---------------|-------|
| `ansible/roles/komodo/templates/compose.env.j2` | 8 | SEC, CQ, CS |
| `ansible/inventory/all.yml` | 7 | SEC, CQ, CS |
| `ansible/roles/komodo/tasks/main.yml` | 5 | SEC, CQ |
| `ansible/playbooks/05_app_syncs.yml` | 4 | SEC, CQ, CS |
| `ansible/tasks/komodo_stack_operations.yml` | 3 | CQ, CS |
| `ansible/roles/komodo_auth/tasks/create_api_key.yml` | 3 | SEC, CQ |
| `ansible/roles/komodo_auth/tasks/manage_service_user.yml` | 3 | SEC, CQ |
| `ansible/roles/komodo/templates/komodo-compose.yml.j2` | 3 | SEC, FG |
| `ansible/ansible.cfg` | 3 | SEC, CQ, CS |

## Appendix B: Cross-Cutting Themes

1. **Incomplete 1Password-to-Infisical Migration:** The single most pervasive
   issue. Affects `compose.env.j2`, `05_app_syncs.yml`, and deployment
   reliability for anyone using the default Infisical backend. Referenced in
   SEC-02, CQ-01/08, CS-06/07.

2. **No Automation Safety Net:** No CI, no tests, no backups, no rollbacks. The
   infrastructure has no safety net for changes or failures. Referenced across
   FG-05/06/08/12/13/14.

3. **Secrets in Plaintext Transit and Storage:** HTTP-only API, world-readable
   env file, no `no_log` on sensitive tasks. Referenced in SEC-01/09/18, CQ-06.

4. **Documentation Drift:** Multiple documentation files are out of sync with
   reality, referencing non-existent Makefiles, wrong paths, and stale versions.
   Referenced in CQ-12/13/14/15, CS-15/16.

5. **Configuration Duplication:** API headers, base URLs, project IDs, yamllint
   configs, and test playbooks all have unnecessary duplication. Referenced
   across CS-02/03/04/06/11/15.
