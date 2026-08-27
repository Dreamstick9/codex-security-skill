# Codex Security CLI Reference

The `@openai/codex-security` CLI provides a unified command line interface for vulnerability scanning, validation, patch generation, false-positive triage, and history tracking.

## Invocation

```bash
# Run directly via npx:
npx @openai/codex-security <command> [options]

# Or install globally / locally:
npm install -g @openai/codex-security
codex-security <command> [options]
```

---

## Global Options

| Option | Type | Description |
| :--- | :--- | :--- |
| `--help`, `-h` | boolean | Show help information. |
| `--version` | boolean | Print installed package and plugin versions. |
| `--json` | boolean | Format output as JSON (where supported). |
| `--dry-run` | boolean | Perform local preflight checks without model execution or network calls. |

---

## Commands

### 1. `scan [repository]`

Run a security scan on a repository or current directory.

```bash
npx @openai/codex-security scan [path] [options]
```

#### Scan Targets & Scoping
- `[path]`: Path to repository or directory (defaults to current working directory `.`).
- `--path <path>`: Scope scan to specific directory or file relative to repository root. Repeatable.
- `--diff <git-ref>`: Scan committed changes against a Git ref (e.g., `origin/main`, `HEAD~1`).
- `--working-tree`: Scan staged and unstaged working-tree modifications.
- `--head <ref>` / `--base <ref>`: Specific head and base commits for diff-based scanning.

#### Scan Modes & Execution Limits
- `--mode <standard|deep>`: Scan mode (`standard` default; `deep` for multi-pass exploration).
- `--workers <count>`: Number of concurrent discovery workers (in deep mode or component scans).
- `--subagents <count>`: Subagents allocated per worker in deep mode.
- `--max-cost <usd>`: Stop scan when estimated LLM cost exceeds this threshold in USD (e.g., `10.00`).
- `--max-time-hours <hours>`: Max deep scan runtime in hours (up to 96 hours).
- `--stop-after-no-new <count>`: In deep mode, stop after `N` consecutive passes find no new vulnerabilities.
- `--max-discovery-runs <count>`: Max total discovery iterations in deep mode.

#### Context & Knowledge Base
- `--knowledge-base <path>`: Path to architecture document, threat model, or security policy (Markdown, PDF, docx, txt). Repeatable.
- `--scan-prompt-file <path>`: Custom instructions injected into discovery workers.
- `--validation-prompt-file <path>`: Custom instructions injected into validation phase.
- `--post-scan-prompt-file <path>`: Custom instructions for final report synthesis.

#### Output & Results
- `--output-dir <dir>`: Directory where scan results and reports are saved. **Must be outside target repository.**
- `--archive-existing`: Move prior results in `output-dir` to an archive timestamped directory rather than failing.
- `--fail-on-severity <critical|high|medium|low>`: Exit with return code `1` if completed scan detects issues at or above specified severity.

#### Remediation & Patching
- `--patch`: Attempt to generate automated, verified fixes for identified vulnerabilities.
- `--patch-severity <critical|high|medium|low>`: Minimum severity threshold to generate patches for.
- `--create-pr`: Create a draft GitHub pull request containing verified patches.

#### Model & Inference Provider Settings
- `--provider <openai|openrouter|fireworks|amazon-bedrock>`: Inference backend (default: `openai`).
- `--model <model-name>`: Specific model identifier.
- `--effort <minimal|low|medium|high|xhigh|max>`: Model reasoning effort level (default: `high`).
- `--auth <auto|chatgpt|api-key>`: Authentication source.
- `--safety-identifier <id>`: Stable hashed end-user identifier for multi-tenant billing/safety tracking.
- `--codex <KEY=VALUE>`: Deep-merge override settings into Codex config (e.g., `--codex model_reasoning_effort="high"`).

---

### 2. `scan-components <repository>`

Decompose large projects or monorepos into distinct components and scan each in isolation with deduplicated global finding matching.

```bash
# Auto-plan components:
npx @openai/codex-security scan-components /path/to/repo --auto --plan-only --output-dir /tmp/plan

# Run scan with plan:
npx @openai/codex-security scan-components /path/to/repo \
  --components-file /tmp/plan/components.json \
  --workers 4 \
  --output-dir /tmp/component-results
```

#### Options:
- `--component <path>`: Explicitly define a component directory. Repeatable.
- `--auto`: Automatically detect project components and boundaries.
- `--plan-only`: Generate and save the component plan without executing scans.
- `--components-file <file.json>`: Path to custom JSON component configuration.

---

### 3. `findings`

Manage findings across repository scans.

- **List Open Findings**:
  ```bash
  npx @openai/codex-security findings list [repository]
  ```
- **Mark False Positive**:
  ```bash
  npx @openai/codex-security findings false-positive <occurrence-id> --reason "<explanation>"
  ```

---

### 4. `scans`

Inspect historical scans and session logs.

- **List Scans**:
  ```bash
  npx @openai/codex-security scans list [repository] [--scan-root <dir>]
  ```
- **Show Scan Details**:
  ```bash
  npx @openai/codex-security scans show <scan-id> [--show-linked-findings]
  ```
- **View Scan Logs & Worker Activity**:
  ```bash
  npx @openai/codex-security scans logs <scan-id>
  ```

---

### 5. `export`

Export finding data from a completed scan directory into standard formats.

```bash
npx @openai/codex-security export \
  --scan-dir /path/to/results \
  --format <sarif|json|csv> \
  --output <file-path|->
```

---

### 6. `login` & `logout`

Manage authentication and credential storage.

```bash
# Interactive browser OAuth
npx @openai/codex-security login

# Headless / remote device authentication
npx @openai/codex-security login --device-auth

# Store API key from stdin
printenv OPENAI_API_KEY | npx @openai/codex-security login --with-api-key

# Check login status
npx @openai/codex-security login status

# Log out and clear stored tokens
npx @openai/codex-security logout
```

---

### 7. `publish`

Publish scan findings to issue trackers.

```bash
# Publish to Linear
npx @openai/codex-security publish scan <scan-id> \
  --to linear \
  --linear-team <team-id> \
  --linear-project <project-id>
```

---

## Exit Codes

| Code | Meaning |
| :--- | :--- |
| `0` | Scan completed successfully with no policy failure (or findings below `--fail-on-severity`). |
| `1` | Scan completed successfully and found vulnerabilities matching or exceeding `--fail-on-severity`. |
| `2` | Scan incomplete, configuration error, missing dependencies, or invalid parameters. |
| `130` | Interrupted by `SIGINT` (Ctrl+C). |
| `143` | Terminated by `SIGTERM`. |
