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

The `codex-security` skill provides procedures for security scanning, vulnerability discovery, evidence-based validation, and automated patch remediation with `@openai/codex-security@0.1.20` (Codex `0.148.0-alpha.8`, plugin `0.1.37`).

## Principles of Operation

1. **Scan Modes**:
   - **Standard Mode (`scan .` / `mode: "standard"`)**: Single-pass audit. Supports repo + `--path` targets + knowledge bases.
   - **Deep Mode (`scan . --mode deep` / `mode: "deep"`)**: Multi-pass concurrent audit with worker subagents. Configure via `--workers`, `--subagents`, `--max-cost`, `--max-time-hours`, `--stop-after-no-new`, `--max-discovery-runs`.
   - **Diff Scan (`scan . --diff <ref>` / `--working-tree`)**: Targeted audit of changed files or uncommitted modifications. Uses `--head`/`--base` to pin refs.
   - **Component Scan (`scan-components .`)**: Split audit for large monorepos with deduplicated findings (via `fingerprints.primary`).

2. **Artifact Isolation**:
   - Always store scan output directories **outside** the target repository (e.g. `/tmp/codex-security-scans/<repo>_<ts>`). The CLI enforces `requireOutputOutsideRepository`; in-repo outputs error with `OutputInsideProtectedRootError`.
   - Output directories must be empty before execution (or pass `--archive-existing`). Worker creates `chmod 700` and rejects shared-parent ancestry (`requireSecureOutputAncestry`).
   - In CI, pass `--headless` to disable the Ink dashboard and `--dry-run` to preflight without spending.

3. **Validation Dispositions**:
   - Every candidate finding receives an evidence-based disposition (from `references/validation-rubric.md`):
     - `reportable`: Validated vulnerability with reproducible proof or confirmed static trace.
     - `suppressed`: Dismissed by verified control or recorded triage rule (`findings false-positive`).
     - `not_applicable`: Dead, unmounted, or unreachable code.
     - `deferred`: Requires external infra unavailable during scan.

4. **Defaults That Matter** (verified via `npx @openai/codex-security info` / `--help`):
   - Model: `gpt-5.6-sol` • Effort: `xhigh` (not `high`) • Provider: `openai` • Node: `^22.13.0 || ^24.0.0 || ^26.0.0` • Python: `3.10+`.
   - `scan --output-dir` defaults to Codex state dir if omitted; explicit dir recommended for CI.
   - Export flags are `--export-format` + positional `scanDir`, not `--scan-dir`/`--format`.

5. **Reference Documentation**:
   - [CLI Reference](./references/cli-reference.md) – full command surface verified against `--help`.
   - [TypeScript SDK Reference](./references/sdk-reference.md) – `CodexSecurity`, `runComponentScans`, `publishScan`, etc.
   - [Finding Schema](./references/finding-schema.md) – `findings.json` / `coverage.json` / `scan-manifest.json` schemas.
   - [Validation Rubric](./references/validation-rubric.md)
   - [Threat Modeling Guide](./references/threat-modeling.md)
   - [Remediation and Patch Risk Guide](./references/remediation-and-patch-risk.md)

---

## Standard Workflows

### 1. Authentication and Setup

Requirements:
- Node.js `^22.13.0 || ^24.0.0 || ^26.0.0` (see `package.json#engines`).
- Python 3.10 or later (`python --version`; override via `--python` or `PYTHON` env).

#### Authentication Procedures

- **Interactive Login**:
  ```bash
  npx @openai/codex-security login
  # verify:
  npx @openai/codex-security login status
  npx @openai/codex-security info
  ```
- **Device Authentication (Headless/CI)**:
  ```bash
  npx @openai/codex-security login --device-auth
  ```
- **API Key via stdin (CI)**:
  ```bash
  printenv OPENAI_API_KEY | npx @openai/codex-security login --with-api-key
  # or just export and use --auth api-key:
  export OPENAI_API_KEY="sk-..."
  npx @openai/codex-security scan . --auth api-key --dry-run
  ```
- **API Key via env (ephemeral, no login required)**:
  ```bash
  export OPENAI_API_KEY="sk-..."
  # OPENAI_API_KEY / CODEX_API_KEY are tried by --auth auto
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
  # alternative: AWS_ACCESS_KEY_ID / AWS_PROFILE / WebIdentity
  ```
- **Preflight without spending** (use in CI before `scan`):
  ```bash
  npx @openai/codex-security scan . --dry-run
  # SDK equivalent: await security.preflight(repo, { mode:"standard" })
  ```

---

### 2. Standard Repository Scan

1. Create a clean output directory **outside the repo**:
   ```bash
   SCAN_OUT="/tmp/codex-security-scans/$(basename "$PWD")_$(date +%Y%m%d_%H%M%S)"
   mkdir -p "$SCAN_OUT" && chmod 700 "$SCAN_OUT"
   ```
2. Run the scan (headless for CI):
   ```bash
   npx @openai/codex-security scan /path/to/repo \
     --output-dir "$SCAN_OUT" \
     --fail-on-severity high \
     --headless
   echo "Exit: $?"  # 0=clean, 1=gate tripped, 2=error
   ```
3. Limit scope to specific paths:
   ```bash
   npx @openai/codex-security scan /path/to/repo \
     --path src/auth \
     --path src/api \
     --output-dir "$SCAN_OUT" \
     --headless
   ```
4. Add threat models or architecture context:
   ```bash
   npx @openai/codex-security scan /path/to/repo \
     --knowledge-base docs/security/threat_model.md \
     --knowledge-base docs/architecture.md \
     --output-dir "$SCAN_OUT" \
     --headless
   ```
5. Inspect results:
   ```bash
   ls -la "$SCAN_OUT"  # findings.json, coverage.json, scan-manifest.json, report.md, findings/<id>/<id>.md
   npx @openai/codex-security scans show --format json | jq .scan
   npx @openai/codex-security export "$SCAN_OUT" --export-format json --output - | jq '.findings | length'
   ```

---

### 3. Pull Request and Diff Reviews

- **Scan Committed Diff** (PR gate):
  ```bash
  npx @openai/codex-security scan /path/to/repo \
    --diff origin/main \
    --output-dir /tmp/pr-scan-results \
    --fail-on-severity high \
    --headless
  # pin refs explicitly if needed:
  # --diff origin/main --head HEAD --base origin/main
  ```
- **Scan Working-Tree Changes** (pre-commit):
  ```bash
  npx @openai/codex-security scan /path/to/repo \
    --working-tree \
    --output-dir /tmp/working-tree-scan \
    --headless
  # alternative: install git hook
  npx @openai/codex-security install-hook /path/to/repo --fail-on-severity high
  ```

Use `scan --dry-run` in PR CI to fail fast on arg errors before spending.

---

### 4. Deep Multi-Worker Scan

Extended search for high-risk repos. Deep respects per-scan cost/time caps and stops early after N idle passes.

```bash
npx @openai/codex-security scan /path/to/repo \
  --mode deep \
  --workers 4 \
  --subagents 2 \
  --max-cost 25.00 \
  --max-time-hours 12 \
  --stop-after-no-new 3 \
  --max-discovery-runs 10 \
  --output-dir /tmp/deep-scan-results \
  --headless
```

SDK equivalent: `await security.run(repo, { mode:"deep", workers:4, subagents:2, maxCostUsd:25, maxTimeHours:12 })` with `onWorkerStatus`/`onSessionEvent` observers.

---

### 5. Multi-Component Scanning for Monorepos

1. Generate the component plan (auto):
   ```bash
   npx @openai/codex-security scan-components /path/to/repo \
     --auto \
     --plan-only \
     --output-dir /tmp/monorepo-plan
   cat /tmp/monorepo-plan/components.json
   ```
2. Run the component scans:
   ```bash
   npx @openai/codex-security scan-components /path/to/repo \
     --components-file /tmp/monorepo-plan/components.json \
     --workers 4 \
     --output-dir /tmp/monorepo-scan-results \
     --headless
   # auto without pre-made plan:
   npx @openai/codex-security scan-components /path/to/repo --auto --workers 4 --output-dir /tmp/mono-auto
   ```
3. Manual plan shape (`examples/components_plan.json`):
   ```json
   { "components": [{ "name": "Web", "paths": ["apps/web"] }, { "name": "API", "paths": ["apps/api"] }] }
   ```

SDK: `await runComponentScans({ repository, outputDir, components, workers:4, scanOptions:{ maxCostUsd:5 } })`.

---

### 6. Finding Management and Triage

- **List Open Findings** (across saved scans for a repo):
  ```bash
  npx @openai/codex-security findings list /path/to/repo
  npx @openai/codex-security findings list /path/to/repo --format json --filter-output findings
  ```
- **List Previous Scans**:
  ```bash
  npx @openai/codex-security scans list /path/to/repo
  npx @openai/codex-security scans list /path/to/repo --scan-root /tmp/codex-security-scans
  ```
- **Display Scan Details**:
  ```bash
  npx @openai/codex-security scans show <scanId> --show-linked-findings
  npx @openai/codex-security scans show --format json --filter-output scan,findings
  ```
- **Stream Scan Logs**:
  ```bash
  npx @openai/codex-security scans logs <scanId>
  ```
- **Compare / Match Scans**:
  ```bash
  npx @openai/codex-security scans compare <beforeId> <afterId>
  npx @openai/codex-security scans match --all
  npx @openai/codex-security scans rerun <scanId> --verbose
  ```
- **Register False Positive** (persists to workbench DB):
  ```bash
  npx @openai/codex-security findings false-positive <occurrenceId> \
    --reason "Input is validated by API gateway Zod schema before reaching this function."
  # occurrenceId format: occ_[a-f0-9]{24} (see findings.json)
  ```

---

### 7. Exporting Findings

**Correct flags** (verified): `export [scanDir] --export-format <sarif|json|csv> --output <file|->`. The old `--scan-dir`/`--format` aliases do **not** exist.

- **SARIF (GitHub Code Scanning)**:
  ```bash
  npx @openai/codex-security export /tmp/scan-results --export-format sarif --output results.sarif --source-root /path/to/repo
  # upload:
  # gh api repos/{owner}/{repo}/code-scanning/sarifs --input results.sarif
  # or via actions/upload-sarif in CI
  ```
- **JSON and CSV**:
  ```bash
  npx @openai/codex-security export /tmp/scan-results --export-format json --output findings.json
  npx @openai/codex-security export /tmp/scan-results --export-format csv  --output findings.csv
  npx @openai/codex-security export --export-format json --output - | jq .
  ```

Helper scripts updated: `scripts/export_sarif.sh <scanDir> [outputFile]` now uses `--export-format`.

---

### 8. Automated Remediation

Synthesize and verify fixes **inline with a scan**:

```bash
npx @openai/codex-security scan /path/to/repo \
  --patch \
  --patch-severity high \
  --create-pr \
  --output-dir /tmp/remediation-scan \
  --headless
```

**Standalone patching** (from saved scan or Linear):

```bash
# From saved scan id
npx @openai/codex-security patch --scan <scanId> --severity high --create-pr

# From Linear
npx @openai/codex-security patch --linear-project <projectId> --linear-api-key "$CODEX_SECURITY_LINEAR_API_KEY" --create-pr

# From explicit issue text/file
npx @openai/codex-security patch "Fix SQL injection in src/db/users.ts:88" --create-pr
```

**Verify fixes without mutating the repo**:

```bash
npx @openai/codex-security verify-fix --scan <scanId> --severity high
npx @openai/codex-security verify-fix --linear-project <projectId>
```

**Validate a candidate finding** (standalone, no repo mutation):

```bash
npx @openai/codex-security validate "Finding text or file containing candidate" --effort high
# SDK: await security.validate({ repositoryPath, finding, outputDir })
```

See `references/remediation-and-patch-risk.md` for patch-risk dimensions and regression gates.

---

### 9. Bulk Scans, Publishing, and Hooks

- **Bulk scan** (resumable, for org-wide sweeps):
  ```bash
  npx @openai/codex-security bulk-scan repositories.csv --output-dir /tmp/bulk --workers 4 --max-attempts 3
  npx @openai/codex-security bulk-scan --output-dir /tmp/bulk  # interactive discovery
  ```
- **Publish to Linear**:
  ```bash
  npx @openai/codex-security publish scan /tmp/scan-results --to linear --linear-team <team-id> --linear-project <project-id> --dry-run
  npx @openai/codex-security publish scan /tmp/scan-results --to linear --linear-team <team-id>
  npx @openai/codex-security publish check /tmp/scan-results --to linear --linear-team <team-id>
  ```
  SDK: `await publishScan(scanDir, { destination:"linear", teamId, projectId })`.
- **Pre-commit hook**:
  ```bash
  npx @openai/codex-security install-hook /path/to/repo --fail-on-severity high
  ```
- **Metadata**:
  ```bash
  npx @openai/codex-security info
  npx @openai/codex-security --llms-full  # full manifest for agents
  ```

---

## Helper Scripts and Examples

- **Scan Script**: [`scripts/run_security_scan.sh`](./scripts/run_security_scan.sh) – safe wrapper with isolation checks, `chmod 700`, `--headless` auto-detection, `--dry-run` and `--archive-existing` support.
- **SARIF Exporter**: [`scripts/export_sarif.sh`](./scripts/export_sarif.sh) – `export <scanDir> [outputFile]` using `--export-format sarif`.
- **Triage Script**: [`scripts/triage_false_positive.sh`](./scripts/triage_false_positive.sh) – `findings false-positive <occ> --reason "..."`.
- **CLI Cookbook**: [`examples/cli_recipes.sh`](./examples/cli_recipes.sh) – recipes for all commands (quick scan, PR diff, deep, components, SARIF, remediation, bulk, publish).
- **SDK Scan Script**: [`examples/sdk_scan_example.ts`](./examples/sdk_scan_example.ts) – `CodexSecurity.run` with preflight + observers.
- **GitHub SARIF Validation Script**: [`examples/sdk_github_validation.ts`](./examples/sdk_github_validation.ts) – validate exported findings and upload SARIF via GitHub API (replaces removed `importGitHubCodeScanningAlerts` pattern).
- **Components Plan**: [`examples/components_plan.json`](./examples/components_plan.json)
