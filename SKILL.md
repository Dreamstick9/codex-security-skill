---
name: codex-security
description: >-
  Automate security vulnerability discovery, code auditing, deep multi-worker scans, PR/commit diff reviews,
  finding validation with evidence/PoCs, automated patching, patch risk assessments, false positive triage,
  GitHub Code Scanning alert imports, and SARIF/JSON/CSV report exports using OpenAI Codex Security CLI and SDK.
  Use when conducting codebase security audits, investigating security findings, reviewing diffs for vulnerabilities,
  validating alerts, or hardening software security boundaries.
---

# Codex Security Skill

The `codex-security` skill provides procedures for security scanning, vulnerability discovery, evidence-based validation, and automated patch remediation with `@openai/codex-security`.

## Principles of Operation

1. **Scan Modes**:
   - **Standard Mode (`scan .` / `mode: "standard"`)**: A single-pass security audit of a repository or defined file paths.
   - **Deep Mode (`scan . --mode deep` / `mode: "deep"`)**: A multi-pass concurrent audit driven by worker subagents.
   - **Diff Scan (`scan . --diff <ref>` / `--working-tree`)**: A targeted audit of changed files or uncommitted modifications.
   - **Component Scan (`scan-components .`)**: A split audit for large monorepos with deduplicated findings.

2. **Artifact Isolation**:
   - Always store scan output directories outside the target source repository (for example, in `/tmp/codex-security-results/<scan_id>`).
   - Output directories must be private (`chmod 700`) and empty before execution.

3. **Validation Dispositions**:
   - Every candidate finding receives an evidence-based disposition:
     - `reportable`: Validated vulnerability with reproducible proof or confirmed static trace.
     - `suppressed`: Finding dismissed by verified security controls or recorded triage rules.
     - `not_applicable`: Code is dead, unmounted, or unreachable in the execution environment.
     - `deferred`: Finding requires external environment setup that is unavailable during the scan.

4. **Reference Documentation**:
   - [CLI Reference](./references/cli-reference.md)
   - [TypeScript SDK Reference](./references/sdk-reference.md)
   - [Finding Schema](./references/finding-schema.md)
   - [Validation Rubric](./references/validation-rubric.md)
   - [Threat Modeling Guide](./references/threat-modeling.md)
   - [Remediation and Patch Risk Guide](./references/remediation-and-patch-risk.md)

---

## Standard Workflows

### 1. Authentication and Setup

Requirements:
- Node.js 22.13.0 or later.
- Python 3.10 or later.

#### Authentication Procedures
- **Interactive Login**:
  ```bash
  npx @openai/codex-security login
  ```
- **Device Authentication (Headless)**:
  ```bash
  npx @openai/codex-security login --device-auth
  ```
- **API Key Configuration**:
  ```bash
  export OPENAI_API_KEY="sk-..."
  ```
- **Third-Party Inference Providers**:
  ```bash
  # OpenRouter
  export OPENROUTER_API_KEY="..."
  npx @openai/codex-security scan . --provider openrouter --model anthropic/claude-sonnet-4.5

  # AWS Bedrock
  export AWS_BEARER_TOKEN_BEDROCK="..."
  export AWS_REGION="us-east-2"
  npx @openai/codex-security scan . --provider amazon-bedrock --model openai.gpt-5.6-luna
  ```

---

### 2. Standard Repository Scan

1. Create a clean output directory:
   ```bash
   SCAN_OUT="/tmp/codex-security-$(date +%s)"
   mkdir -p "$SCAN_OUT"
   ```
2. Run the scan command:
   ```bash
   npx @openai/codex-security scan /path/to/repo \
     --output-dir "$SCAN_OUT" \
     --fail-on-severity high
   ```
3. To limit scope to specific paths:
   ```bash
   npx @openai/codex-security scan /path/to/repo \
     --path src/auth \
     --path src/api \
     --output-dir "$SCAN_OUT"
   ```
4. To add threat models or architecture context:
   ```bash
   npx @openai/codex-security scan /path/to/repo \
     --knowledge-base docs/security/threat_model.md \
     --output-dir "$SCAN_OUT"
   ```

---

### 3. Pull Request and Diff Reviews

- **Scan Committed Diff**:
  ```bash
  npx @openai/codex-security scan /path/to/repo \
    --diff origin/main \
    --output-dir /tmp/pr-scan-results
  ```
- **Scan Working-Tree Changes**:
  ```bash
  npx @openai/codex-security scan /path/to/repo \
    --working-tree \
    --output-dir /tmp/working-tree-scan
  ```

---

### 4. Deep Multi-Worker Scan

Execute an extended search on high-risk repositories:

```bash
npx @openai/codex-security scan /path/to/repo \
  --mode deep \
  --workers 4 \
  --subagents 2 \
  --max-cost 25.00 \
  --max-time-hours 12 \
  --stop-after-no-new 3 \
  --output-dir /tmp/deep-scan-results
```

---

### 5. Multi-Component Scanning for Monorepos

1. Generate the component plan:
   ```bash
   npx @openai/codex-security scan-components /path/to/repo \
     --auto \
     --plan-only \
     --output-dir /tmp/monorepo-plan
   ```
2. Run the component scans:
   ```bash
   npx @openai/codex-security scan-components /path/to/repo \
     --components-file /tmp/monorepo-plan/components.json \
     --workers 4 \
     --output-dir /tmp/monorepo-scan-results
   ```

---

### 6. Finding Management and Triage

- **List Open Findings**:
  ```bash
  npx @openai/codex-security findings list /path/to/repo
  ```
- **List Previous Scans**:
  ```bash
  npx @openai/codex-security scans list /path/to/repo
  ```
- **Display Scan Details**:
  ```bash
  npx @openai/codex-security scans show <scan-id> --show-linked-findings
  ```
- **Register False Positive**:
  ```bash
  npx @openai/codex-security findings false-positive <occurrence-id> \
    --reason "Input is validated by API gateway middleware before reaching this function."
  ```

---

### 7. Exporting Findings

- **SARIF (GitHub Code Scanning)**:
  ```bash
  npx @openai/codex-security export \
    --scan-dir /tmp/scan-results \
    --format sarif \
    --output results.sarif
  ```
- **JSON and CSV**:
  ```bash
  npx @openai/codex-security export --scan-dir /tmp/scan-results --format json --output findings.json
  npx @openai/codex-security export --scan-dir /tmp/scan-results --format csv --output findings.csv
  ```

---

### 8. Automated Remediation

Synthesize patches and verify fixes:

```bash
npx @openai/codex-security scan /path/to/repo \
  --patch \
  --patch-severity high \
  --create-pr \
  --output-dir /tmp/remediation-scan
```

---

## Helper Scripts and Examples

- **Scan Script**: [`scripts/run_security_scan.sh`](./scripts/run_security_scan.sh)
- **SARIF Exporter**: [`scripts/export_sarif.sh`](./scripts/export_sarif.sh)
- **Triage Script**: [`scripts/triage_false_positive.sh`](./scripts/triage_false_positive.sh)
- **CLI Cookbook**: [`examples/cli_recipes.sh`](./examples/cli_recipes.sh)
- **SDK Scan Script**: [`examples/sdk_scan_example.ts`](./examples/sdk_scan_example.ts)
- **GitHub Alert Validation Script**: [`examples/sdk_github_validation.ts`](./examples/sdk_github_validation.ts)
