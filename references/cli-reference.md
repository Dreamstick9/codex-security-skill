# Codex Security CLI Reference

The `@openai/codex-security` command-line interface provides tools for vulnerability discovery, finding validation, patch generation, and scan history tracking.

## Invocation

```bash
# Run with npx:
npx @openai/codex-security <command> [options]

# Or install globally:
npm install -g @openai/codex-security
codex-security <command> [options]
```

---

## Global Options

| Option | Type | Description |
| :--- | :--- | :--- |
| `--help`, `-h` | boolean | Show command help. |
| `--version` | boolean | Print installed package and plugin versions. |
| `--json` | boolean | Output results as JSON. |
| `--dry-run` | boolean | Perform local validation checks without running models or network calls. |

---

## Commands

### 1. `scan [repository]`

Execute a security scan on a repository path or current directory.

```bash
npx @openai/codex-security scan [path] [options]
```

#### Scan Targets
- `[path]`: Path to repository directory. Defaults to current working directory (`.`).
- `--path <path>`: Limit scan to specific relative file or folder. Repeat flag for multiple paths.
- `--diff <git-ref>`: Scan files changed against a Git reference (for example, `origin/main`).
- `--working-tree`: Scan uncommitted staged and unstaged changes.
- `--head <ref>` / `--base <ref>`: Set explicit head and base commits for diff scans.

#### Scan Modes and Resource Limits
- `--mode <standard|deep>`: Select scan mode (`standard` or `deep`). Default is `standard`.
- `--workers <count>`: Number of concurrent discovery workers.
- `--subagents <count>`: Number of subagents per discovery worker in deep mode.
- `--max-cost <usd>`: Stop scan when estimated LLM cost exceeds this value in USD.
- `--max-time-hours <hours>`: Maximum deep scan duration in hours (up to 96 hours).
- `--stop-after-no-new <count>`: Stop deep scan after `N` consecutive passes find no new vulnerabilities.
- `--max-discovery-runs <count>`: Maximum discovery iterations in deep mode.

#### Context and Knowledge Base
- `--knowledge-base <path>`: Path to architecture documentation or threat models. Repeat flag for multiple files.
- `--scan-prompt-file <path>`: Custom instructions for discovery workers.
- `--validation-prompt-file <path>`: Custom instructions for validation workers.
- `--post-scan-prompt-file <path>`: Custom instructions for final report synthesis.

#### Output Configuration
- `--output-dir <dir>`: Directory path for scan artifacts. Do not place this directory inside the target repository.
- `--archive-existing`: Move existing results in the output directory to an archive path.
- `--fail-on-severity <critical|high|medium|low>`: Return exit code `1` if findings match or exceed specified severity.

#### Remediation and Patching
- `--patch`: Generate verified code fixes for discovered vulnerabilities.
- `--patch-severity <critical|high|medium|low>`: Minimum severity threshold required for patch generation.
- `--create-pr`: Create a draft GitHub pull request with verified patches.

#### Model and Provider Configuration
- `--provider <openai|openrouter|fireworks|amazon-bedrock>`: LLM provider (default: `openai`).
- `--model <model-name>`: Model identifier.
- `--effort <minimal|low|medium|high|xhigh|max>`: Reasoning effort level (default: `high`).
- `--auth <auto|chatgpt|api-key>`: Credential source.
- `--safety-identifier <id>`: User identifier string for multi-tenant tracking.
- `--codex <KEY=VALUE>`: Configuration overrides for the Codex engine.

---

### 2. `scan-components <repository>`

Split large repositories into components and scan each component separately.

```bash
# Generate component plan:
npx @openai/codex-security scan-components /path/to/repo --auto --plan-only --output-dir /tmp/plan

# Run scans from plan file:
npx @openai/codex-security scan-components /path/to/repo \
  --components-file /tmp/plan/components.json \
  --workers 4 \
  --output-dir /tmp/component-results
```

#### Options:
- `--component <path>`: Define a component path. Repeat flag for multiple components.
- `--auto`: Automatically detect component boundaries.
- `--plan-only`: Create the plan file without executing scans.
- `--components-file <file.json>`: Path to input JSON plan file.

---

### 3. `findings`

Manage findings across scan runs.

- **List Open Findings**:
  ```bash
  npx @openai/codex-security findings list [repository]
  ```
- **Mark Finding as False Positive**:
  ```bash
  npx @openai/codex-security findings false-positive <occurrence-id> --reason "<explanation>"
  ```

---

### 4. `scans`

Inspect previous scan records and logs.

- **List Scans**:
  ```bash
  npx @openai/codex-security scans list [repository] [--scan-root <dir>]
  ```
- **Show Scan Summary**:
  ```bash
  npx @openai/codex-security scans show <scan-id> [--show-linked-findings]
  ```
- **Read Scan Logs**:
  ```bash
  npx @openai/codex-security scans logs <scan-id>
  ```

---

### 5. `export`

Export scan findings to file formats.

```bash
npx @openai/codex-security export \
  --scan-dir /path/to/results \
  --format <sarif|json|csv> \
  --output <file-path|->
```

---

### 6. `login` and `logout`

Manage authentication state.

```bash
# Interactive login
npx @openai/codex-security login

# Device authentication
npx @openai/codex-security login --device-auth

# Store API key from standard input
printenv OPENAI_API_KEY | npx @openai/codex-security login --with-api-key

# Check status
npx @openai/codex-security login status

# Log out
npx @openai/codex-security logout
```

---

### 7. `publish`

Send findings to issue tracking platforms.

```bash
npx @openai/codex-security publish scan <scan-id> \
  --to linear \
  --linear-team <team-id> \
  --linear-project <project-id>
```

---

## Exit Codes

| Code | Description |
| :--- | :--- |
| `0` | Scan completed successfully. No findings exceeded the failure severity threshold. |
| `1` | Scan completed successfully. One or more findings exceeded the failure severity threshold. |
| `2` | Scan failed due to invalid arguments, missing dependencies, or execution errors. |
| `130` | Execution stopped by `SIGINT` (Ctrl+C). |
| `143` | Execution stopped by `SIGTERM`. |
