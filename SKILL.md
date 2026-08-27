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

The `codex-security` skill enables comprehensive static and dynamic security analysis, vulnerability discovery, evidence-based validation, automated patch remediation, and scan lifecycle management using the `@openai/codex-security` CLI and TypeScript SDK.

## Core Concepts & Operating Principles

1. **Security Scan Modes**:
   - **Standard Mode (`scan .` / `mode: "standard"`)**: A single-pass security audit across the repository or scoped paths. Identifies vulnerabilities, validates findings, and generates a structured report.
   - **Deep Mode (`scan . --mode deep` / `mode: "deep"`)**: Multi-pass, concurrent discovery driven by worker subagents (up to 96 hours max discovery time, customizable `--workers`, `--subagents`, `--stop-after-no-new`).
   - **Diff Scan (`scan . --diff <ref>` / `--working-tree`)**: Focused incremental audit reviewing only modified files or unstaged changes.
   - **Component Scan (`scan-components .`)**: Decomposes monorepos or large multi-package projects into scoped components with automated deduplication and combined reporting.

2. **Isolated Artifact Storage**:
   - Always place output scan directories **outside** the scanned Git repository (e.g., `/tmp/codex-security-results/<scan_id>` or `~/.codex-security/scans/<scan_id>`).
   - Output directories must be private (`chmod 700` on macOS/Linux) and empty before scanning (or use `--archive-existing` / `archiveExisting: true`).

3. **Validation & Dispositions**:
   - All candidate findings undergo rigorous evidence-based validation:
     - `reportable`: Validated vulnerability with reproducible proof or rigorous static source-to-sink trace.
     - `suppressed`: Finding dismissed based on existing security controls or recorded false-positive feedback.
     - `not_applicable`: Code path unreachable or prerequisites impossible in target environment.
     - `deferred`: Insufficient evidence or unprovable dynamic state without full environment.

4. **Progressive Disclosure References**:
   - Complete CLI documentation: [CLI Reference](./references/cli-reference.md)
   - TypeScript SDK API & Types: [SDK Reference](./references/sdk-reference.md)
   - Vulnerability Finding Schemas: [Finding Schema](./references/finding-schema.md)
   - Validation Rubrics & Proof Methods: [Validation Rubric](./references/validation-rubric.md)
   - Threat Modeling & Attack Paths: [Threat Modeling Guide](./references/threat-modeling.md)
   - Patch Remediation & Risk Analysis: [Remediation & Patch Risk Guide](./references/remediation-and-patch-risk.md)

---

## Step-by-Step Workflows

### 1. Prerequisites & Authentication

Codex Security requires **Node.js 22.13.0+** and **Python 3.10+**.

#### Authentication Methods
- **ChatGPT OAuth Login (Interactive / Local)**:
  ```bash
  npx @openai/codex-security login
  # Or for remote/headless sessions:
  npx @openai/codex-security login --device-auth
  ```
- **API Key (CI/CD or Non-Interactive)**:
  ```bash
  export OPENAI_API_KEY="sk-..."
  # Or save key to private credential storage:
  printenv OPENAI_API_KEY | npx @openai/codex-security login --with-api-key
  ```
- **Alternative Providers (OpenRouter, Fireworks, AWS Bedrock)**:
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

### 2. Running a Standard Repository Scan

To scan an entire repository or target folder:

1. Create a dedicated output directory outside the repository:
   ```bash
   SCAN_OUT="/tmp/codex-security-$(date +%s)"
   mkdir -p "$SCAN_OUT"
   ```
2. Execute the scan:
   ```bash
   npx @openai/codex-security scan /path/to/repo \
     --output-dir "$SCAN_OUT" \
     --fail-on-severity high
   ```
3. For scoped audits, specify one or more `--path` arguments:
   ```bash
   npx @openai/codex-security scan /path/to/repo \
     --path src/auth \
     --path src/api \
     --output-dir "$SCAN_OUT"
   ```
4. Include security architecture or policy context via `--knowledge-base`:
   ```bash
   npx @openai/codex-security scan /path/to/repo \
     --knowledge-base docs/security/threat_model.md \
     --output-dir "$SCAN_OUT"
   ```

---

### 3. Reviewing PRs and Working Tree Diffs

Run targeted incremental scans during code review or pre-commit checks:

- **Scan Committed Diff Against Base Branch**:
  ```bash
  npx @openai/codex-security scan /path/to/repo \
    --diff origin/main \
    --output-dir /tmp/pr-scan-results
  ```
- **Scan Uncommitted Working-Tree Changes**:
  ```bash
  npx @openai/codex-security scan /path/to/repo \
    --working-tree \
    --output-dir /tmp/working-tree-scan
  ```

---

### 4. Deep Multi-Worker Security Audits

For thorough, multi-pass exploration on high-criticality assets:

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

### 5. Monorepo Multi-Component Scanning

When dealing with large monorepos with multiple services/libraries:

1. **Auto-Generate a Component Plan**:
   ```bash
   npx @openai/codex-security scan-components /path/to/repo \
     --auto \
     --plan-only \
     --output-dir /tmp/monorepo-plan
   ```
2. **Execute Component Scans with Shared Matching**:
   ```bash
   npx @openai/codex-security scan-components /path/to/repo \
     --components-file /tmp/monorepo-plan/components.json \
     --workers 4 \
     --output-dir /tmp/monorepo-scan-results
   ```

---

### 6. Validating Findings & Triaging False Positives

#### Inspecting Findings History
```bash
# List open findings across repository scans
npx @openai/codex-security findings list /path/to/repo

# List historical scans
npx @openai/codex-security scans list /path/to/repo

# View specific scan details
npx @openai/codex-security scans show <scan-id> --show-linked-findings
```

#### Dismissing False Positives
To prevent dismissed findings from reappearing in future scans:
```bash
npx @openai/codex-security findings false-positive <occurrence-id> \
  --reason "Input is sanitized by ApiGateway validation middleware before reaching this handler."
```

---

### 7. Exporting Findings to SARIF, JSON, and CSV

Codex Security generates native formats and exports:

- **SARIF (GitHub Code Scanning upload)**:
  ```bash
  npx @openai/codex-security export \
    --scan-dir /tmp/scan-results \
    --format sarif \
    --output results.sarif
  ```
- **JSON & CSV**:
  ```bash
  npx @openai/codex-security export --scan-dir /tmp/scan-results --format json --output findings.json
  npx @openai/codex-security export --scan-dir /tmp/scan-results --format csv --output findings.csv
  ```

---

### 8. Automated Remediation & Verification

1. **Generate Minimal Verified Patches**:
   ```bash
   npx @openai/codex-security scan /path/to/repo \
     --patch \
     --patch-severity high \
     --create-pr \
     --output-dir /tmp/remediation-scan
   ```
2. **Assess Patch Risk**:
   Evaluates patch changes for behavioral breakage, edge case regressions, or introduced side effects.

---

### 9. TypeScript SDK Programmatic Workflow

```ts
import { CodexSecurity } from "@openai/codex-security";

const security = new CodexSecurity({
  codexOverrides: {
    model_reasoning_effort: "high",
  },
});

try {
  // Preflight check
  const preflight = await security.preflight("/path/to/repo", {
    mode: "standard",
  });
  console.log("Preflight status:", preflight);

  // Execute scan with cost ceiling and event observation
  const result = await security.run("/path/to/repo", {
    outputDir: "/tmp/codex-security-output",
    maxCostUsd: 10.0,
    onWorkerStatus: (status) => console.log(`Worker ${status.workerNumber}: ${status.phase}`),
  });

  console.log(`Scan completed: ${result.scanId}`);
  console.log(`Report path: ${result.reportPath}`);
  console.log(`Findings count: ${result.findings.findings.length}`);
} finally {
  await security.close();
}
```

---

## Helper Scripts & Examples

- **Quick Scan Helper**: [`run_security_scan.sh`](./scripts/run_security_scan.sh)
- **SARIF Exporter**: [`export_sarif.sh`](./scripts/export_sarif.sh)
- **False Positive Helper**: [`triage_false_positive.sh`](./scripts/triage_false_positive.sh)
- **CLI Cookbook**: [`cli_recipes.sh`](./examples/cli_recipes.sh)
- **SDK Scan Script**: [`sdk_scan_example.ts`](./examples/sdk_scan_example.ts)
- **GitHub Alert Validation Script**: [`sdk_github_validation.ts`](./examples/sdk_github_validation.ts)
