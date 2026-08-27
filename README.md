# OpenAI Codex Security Skill

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Agent Skill](https://img.shields.io/badge/Agent_Skill-Universal-purple.svg)](#agent-compatibility-and-installation)
[![npm package](https://img.shields.io/badge/npm-%40openai%2Fcodex--security-red)](https://www.npmjs.com/package/@openai/codex-security)

This repository contains a universal technical skill and workflow toolkit for `@openai/codex-security`.

The skill allows automated AI coding agents, developers, and CI/CD pipelines to:
- Find security vulnerabilities in source code.
- Execute multi-worker deep security scans.
- Audit pull request diffs and working tree modifications.
- Validate candidate findings with reproducible evidence.
- Generate and verify security patches.
- Assess patch risk and open pull requests.
- Export findings in SARIF, JSON, and CSV formats.

---

## Agent Compatibility and Installation

This skill uses the standard Agent Skill Specification (`SKILL.md` with structured YAML metadata and reference documentation). It is compatible with all AI coding agents that support skill discovery.

| Environment | Directory Path |
| :--- | :--- |
| Universal Agent Standard | `.agents/skills/codex-security/` |
| Claude Code | `.claude/skills/codex-security/` or `~/.claude/skills/` |
| Cursor / Windsurf / Cline / Roo | `.agents/skills/codex-security/` |
| Antigravity | `.agents/skills/codex-security/` or `~/.gemini/config/skills/` |
| Global User Configuration | `~/.agents/skills/codex-security/` |

### Installation

#### 1. Workspace Level (Single Project)
Clone this repository into your project directory:

```bash
# Standard universal agent directory:
mkdir -p .agents/skills
git clone https://github.com/Dreamstick9/codex-security-skill.git .agents/skills/codex-security

# For Claude Code:
mkdir -p .claude/skills
git clone https://github.com/Dreamstick9/codex-security-skill.git .claude/skills/codex-security
```

#### 2. Global Level (All Projects)
Clone this repository into your user directory:

```bash
mkdir -p ~/.agents/skills
git clone https://github.com/Dreamstick9/codex-security-skill.git ~/.agents/skills/codex-security
```

---

## Repository Structure

```text
codex-security-skill/
├── SKILL.md                          # Main skill instruction file
├── references/
│   ├── cli-reference.md              # CLI commands, options, and parameters
│   ├── sdk-reference.md              # TypeScript SDK classes and interfaces
│   ├── finding-schema.md             # Finding data structures and severity definitions
│   ├── validation-rubric.md          # Evidence hierarchy and validation rules
│   ├── threat-modeling.md            # Threat model analysis and attack paths
│   └── remediation-and-patch-risk.md # Patch synthesis and risk evaluation
├── examples/
│   ├── cli_recipes.sh                # Shell command examples
│   ├── sdk_scan_example.ts           # TypeScript SDK execution example
│   ├── sdk_github_validation.ts      # GitHub alert validation example
│   └── components_plan.json          # Multi-component configuration example
└── scripts/
    ├── run_security_scan.sh          # Scan runner script
    ├── export_sarif.sh               # SARIF export script
    └── triage_false_positive.sh      # False positive registration script
```

---

## Quick Start

### Prerequisites
- Node.js `^22.13.0 || ^24.0.0 || ^26.0.0` (see package.json#engines).
- Python version 3.10 or later.
- Valid OpenAI API credentials or ChatGPT account.

### Authentication

Set the API key in your environment:
```bash
export OPENAI_API_KEY="sk-..."
```

Or authenticate interactively:
```bash
npx @openai/codex-security login
```

For headless environments, use device authentication:
```bash
npx @openai/codex-security login --device-auth
```

### 1. Execute a Standard Scan

Run a single-pass security scan on a repository:

```bash
npx @openai/codex-security scan /path/to/project \
  --output-dir /tmp/scan-results \
  --fail-on-severity high
```

Alternatively, use the included shell script:
```bash
./scripts/run_security_scan.sh /path/to/project
```

### 2. Execute a Diff Scan

Scan only files changed in a branch or commit:

```bash
npx @openai/codex-security scan /path/to/project \
  --diff origin/main \
  --output-dir /tmp/pr-scan-results
```

Scan uncommitted working tree changes:

```bash
npx @openai/codex-security scan /path/to/project \
  --working-tree \
  --output-dir /tmp/working-tree-scan
```

### 3. Execute a Deep Multi-Worker Scan

Run an extended scan with multiple discovery workers:

```bash
npx @openai/codex-security scan /path/to/project \
  --mode deep \
  --workers 4 \
  --subagents 2 \
  --max-cost 20.00 \
  --max-time-hours 12 \
  --output-dir /tmp/deep-scan-results
```

### 4. Execute a Component Scan

Decompose large projects into distinct components:

```bash
# Step 1: Create the component plan
npx @openai/codex-security scan-components /path/to/project --auto --plan-only --output-dir /tmp/plan

# Step 2: Run scans for all components
npx @openai/codex-security scan-components /path/to/project \
  --components-file /tmp/plan/components.json \
  --workers 4 \
  --output-dir /tmp/component-results
```

### 5. Generate Verified Patches

Synthesize and verify code fixes for high-severity findings:

```bash
npx @openai/codex-security scan /path/to/project \
  --patch \
  --patch-severity high \
  --create-pr \
  --output-dir /tmp/remediation-results
```

---

## Advanced Prompt Library — Complex, Copy-Paste Prompts That Unlock the Skill

> **Why this section exists:** Most users type `scan .` and stop. The skill's real power is in **threat-model-aware deep scans, PR gates, component deduplication, validation hierarchies, patch-risk gates, and publish pipelines**. The prompts below are battle-tested to make an agent do the *full* workflow in one shot — flags, isolation, headless, cost guards, SARIF fingerprints, and SDK observers included. Copy the entire block into your agent.

### How to Use
1. Replace bracketed placeholders like `[REPO]`, `[TEAM_ID]`.
2. Paste the whole prompt to your agent (Claude Code, Cursor, Codex, etc.) — the skill will parse and execute via the correct CLI/SDK.
3. All outputs go **outside the repo** (`/tmp/...`, `chmod 700`) and use `--headless` for CI. Cost is capped via `--max-cost`.

---

### 1. Threat-Model-Guided Deep Audit (Premium — Finds Logic Bugs Others Miss)

**When:** High-risk repo, auth/payment, or before a release. You have a threat model.

**Prompt:**
````markdown
Run a **threat-model-guided deep audit** of [REPO=. ]:

- Preflight with `npx @openai/codex-security scan . --dry-run --output-dir /tmp/preflight` — abort if config errors.
- Then run deep mode: `scan . --mode deep --workers 4 --subagents 2 --max-cost 25.00 --max-time-hours 6 --stop-after-no-new 3 --max-discovery-runs 12` with `--knowledge-base docs/security/threat_model.md --knowledge-base docs/architecture.md --knowledge-base .agents/memory/security.md` if they exist.
- Use `--output-dir /tmp/codex-deep-$(date +%s) --headless --archive-existing --safety-identifier hashed-user-$(whoami) --effort xhigh --model gpt-5.6-sol --fail-on-severity high`
- Stream `onWorkerStatus`, `onProgress`, `onCost` to stderr.
- After: `export /tmp/... --export-format sarif --output $(dirname /tmp/...)/$(basename /tmp/...).sarif --source-root .` and print `findings.json | jq '.findings[] | {severity: .severity.level, rule: .ruleId, path: .locations[0].path}'`.
- Do NOT write inside the repo. Explain any `suppressed` findings vs. `reportable`.
````

**Under the hood:** `scan --mode deep` + knowledge-base + headless + cost guards + SARIF fingerprints.
**Non-obvious:** `--knowledge-base` is repeatable and changes coverage; `--stop-after-no-new` controls deep convergence; sibling SARIF path avoids `cannot overwrite scan artifact` error.

### 2. PR Gate That Actually Blocks Merges (Diff + SARIF + Code Scanning)

**When:** CI pull request quality gate.

**Prompt:**
````markdown
Act as CI gate for PR against origin/main on [REPO=. ]:

1. `git fetch origin main` then `npx @openai/codex-security scan . --diff origin/main --output-dir /tmp/pr-gate --fail-on-severity high --headless --dry-run` first — if dry-run fails, fix args before spending.
2. Real scan: same flags without --dry-run, plus `--knowledge-base docs/security/threat_model.md` if exists.
3. On exit code 1 (gate tripped) — export SARIF to `$(dirname /tmp/pr-gate)/$(basename /tmp/pr-gate).sarif --source-root .` and run `npx @openai/codex-security scans show --format json | jq .scan.findings`.
4. On exit 0 — still export JSON to sibling `.json` for audit.
5. Print: scanId, costUsd, filesScanned, and `findings list --format json` count by severity.
6. If scan fails with `clean repository checkout` error, stash and retry with `--working-tree` fallback and explain.
````

**Under the hood:** `scan --diff` + `--fail-on-severity` exit-code contract (0/1/2/130/143) + `export --export-format sarif --source-root`.
**Non-obvious:** Diff scans require clean checkout; SARIF needs `--source-root` for fingerprints or GitHub shows no path.

### 3. Monorepo Auto-Partition → Component Scan → Deduplication Proof

**When:** Monorepo >5 packages where single scan times out or dedups incorrectly.

**Prompt:**
````markdown
For monorepo [REPO=. ] do **plan-then-scan**:

- Step A: `npx @openai/codex-security scan-components . --auto --plan-only --output-dir /tmp/mono-plan` — print `/tmp/mono-plan/components.json` and ask me to edit if components look wrong (show `examples/components_plan.json` schema).
- Step B: `npx @openai/codex-security scan-components . --components-file /tmp/mono-plan/components.json --workers 4 --output-dir /tmp/mono-results --headless --max-cost 15.00 --knowledge-base docs/security/threat_model.md` — stream ComponentReceipt status.
- Step C: Run `npx @openai/codex-security scans compare <before> <after>` if prior scan exists, or `scans match --all` to prove deduplication via `fingerprints.primary (codex-security/v1:sha256:...)`.
- Explain `deduplication.confirmedGroups` vs `uncertainPairs` from ComponentScanResult.
````

**Under the hood:** `scan-components --auto/--plan-only` + `runComponentScans` + `scans compare/match`.
**Non-obvious:** Plan file is `{"components":[{"name","paths":[]}]}` — `--auto` uses LLM to propose, but human edit improves dedup.

### 4. Scoped Auth/Crypto Audit with Custom Scan Prompt (OWASP Lens)

**When:** You only distrust `src/auth`, `src/middleware`, `src/crypto`.

**Prompt:**
````markdown
Scoped audit of sensitive subsystems in [REPO=. ]:

- Pre-create `/tmp/scan-prompt.md` with: "Focus ONLY on OWASP Top 10 2021: A01 Broken Access Control, A02 Cryptographic Failures, A07 Identification/Authentication Failures. Prioritize IDOR, JWT validation, session fixation, weak crypto, insecure direct object references. Ignore informational low-risk docs."
- Then `npx @openai/codex-security scan . --path src/auth --path src/middleware --path src/crypto --scan-prompt-file /tmp/scan-prompt.md --knowledge-base docs/security/threat_model.md --output-dir /tmp/scoped-auth --headless --fail-on-severity medium`
- Also create `/tmp/post-scan.md` with: "Generate hardening proposal per references/proposal-format.md with attack path, STRIDE, and O(1) fixes only." and pass `--post-scan-prompt-file /tmp/post-scan.md`.
- Export sibling SARIF+JSON and list `findings.json` filtered to `cwe: CWE-287,CWE-306,CWE-327`.
````

**Under the hood:** `--path` repeatable + `--scan-prompt-file` + `--post-scan-prompt-file`.
**Non-obvious:** `--path` limits `includePaths` in coverage; custom prompts are appended, not replaced — keep them short and threat-specific.

### 5. Candidate Validation with Evidence Hierarchy (The Rubric)

**When:** You have a candidate finding and need `reportable/suppressed/not_applicable/deferred` with proof.

**Prompt:**
````markdown
Validate candidate finding against [REPO=. ] using the validation rubric:

- Candidate: file `/tmp/candidate.json` with `{title, location, description}` OR raw text "SQL injection in src/db/users.ts:88 via req.params.id into db.raw".
- Run `npx @openai/codex-security validate /tmp/candidate.json --effort xhigh` AND SDK equivalent `await security.validate({repositoryPath:".", finding: candidate, outputDir:"/tmp/validate-$(date +%s)"})` — show both.
- Apply hierarchy: 1) dynamic crash 2) ASan 3) debugger 4) test harness 5) interface reproduction 6) static source→sink. Require explicit source, unbroken control flow, sanitization absence, concrete sink, gap analysis.
- Output disposition, report markdown first 400 chars, and `outputDir/threadId`.
- If `suppressed`, cite verified sanitizer or schema enforcement (Zod/Pydantic) line number. If `not_applicable`, prove dead code/unmounted route.
````

**Under the hood:** `validate` (CLI) + `security.validate()` (SDK) + `references/validation-rubric.md`.
**Non-obvious:** `validate` finding arg is `string|object` — strings are never file paths; result dispositions are aliased (`disposition/status/result`).

### 6. Bulk Org Scan (Resumable, Discover + CSV)

**When:** Audit 50 repos across an org.

**Prompt:**
````markdown
Bulk scan discovery for org:

- If no CSV given, run `npx @openai/codex-security bulk-scan --output-dir /tmp/bulk --workers 4 --mode standard --max-attempts 3 --headless` interactively and discover repos.
- If CSV given (`repositories.csv` with header `repo,mode`), run `npx @openai/codex-security bulk-scan repositories.csv --output-dir /tmp/bulk --workers 4 --max-attempts 3 --max-cost 10.00`.
- After: `ls /tmp/bulk/*/findings.json | xargs -I {} sh -c 'echo {} && jq ".findings | length" {}'` and `cat /tmp/bulk/bulk-manifest.json | jq .`.
- For any repo that timed out, fallback to `scan-components --auto --workers 2 --output-dir /tmp/bulk-fallback/<repo> --headless`.
````

**Under the hood:** `bulk-scan` + resumable `output-dir` + `ComponentScanResult` fallback.
**Non-obvious:** `bulk-scan` without input does interactive discovery; with CSV it is resumable — keep `output-dir` outside any repo.

### 7. Patch + Risk Gate + Draft PR (One-Shot Remediation)

**When:** You want verified fixes, not just findings.

**Prompt:**
````markdown
Remediation pipeline for [REPO=. ]:

1. Scan with inline patch: `npx @openai/codex-security scan . --mode standard --output-dir /tmp/remed --patch --patch-severity high --create-pr --headless --fail-on-severity high`
2. If scan already completed (scanId [SCAN_ID]), instead run standalone: `npx @openai/codex-security patch --scan [SCAN_ID] --severity high --create-pr --effort xhigh`
3. Then verify without mutation: `npx @openai/codex-security verify-fix --scan [SCAN_ID] --severity high` — require regression tests (npm test/pytest) pass and exploit invariant fails before.
4. Evaluate patch risk per references/remediation-and-patch-risk.md: behavioral impact / API compatibility / performance (O(1) vs O(n)). Only allow low-risk internal private-function changes to auto-merge; medium/high require human review.
5. Export patch diff via `git diff --stat` and `gh pr view --json title,url,state` if --create-pr succeeded.
6. If patch fails, run `npx @openai/codex-security validate "<finding>"` to double-check reportable vs suppressed before re-attempt.
````

**Under the hood:** `scan --patch --patch-severity --create-pr` + `patch` + `verify-fix` + `validate`.
**Non-obvious:** `--create-pr` requires `gh` auth and draft PR; `verify-fix` checks fix *without* changing repo — ideal for CI.

### 8. Linear Publish Pipeline with Dry-Run Safety

**When:** Push findings to Linear as issues.

**Prompt:**
````markdown
Publish findings to Linear for scanDir [/tmp/scan]:

- Pre-check: `npx @openai/codex-security publish check /tmp/scan --to linear --linear-team [TEAM_ID] --linear-project [PROJECT_ID] --linear-api-key $CODEX_SECURITY_LINEAR_API_KEY` — verify transport, team, project, assignee without creating.
- Preview: `npx @openai/codex-security publish scan /tmp/scan --to linear --linear-team [TEAM_ID] --dry-run --skip-existing` — list counts `pending/created/failed/skipped`.
- Real publish: same without --dry-run, capture `publishScan` SDK `onProgress` events (`issue_completed` -> `issueIdentifier`).
- SDK alternative: `await publishScan("/tmp/scan", {destination:"linear", teamId, projectId, linearApiKey, assigneeId, skipExisting:true, onProgress})` and `checkScanPublication` first.
- Print `result.created.length`, `failed`, `skipped`, and warnings. If `skipExisting=true`, explain deduplication via `fingerprints.primary`.
````

**Under the hood:** `publish check/scan` + `publishScan/checkScanPublication` SDK.
**Non-obvious:** Linear keys default to env `CODEX_SECURITY_LINEAR_API_KEY/TEAM/PROJECT`; always `--dry-run` first in production.

### 9. SARIF Export Pipeline for GitHub Code Scanning (Fingerprint-Correct)

**When:** Need GitHub Security tab integration.

**Prompt:**
````markdown
Export and upload for GitHub Code Scanning from scanDir [/tmp/scan] and repo [. ]:

- `npx @openai/codex-security export /tmp/scan --export-format sarif --output $(dirname /tmp/scan)/$(basename /tmp/scan).sarif --source-root .` — explain sibling path avoids inside-scan artifact error.
- Also `npx @openai/codex-security export /tmp/scan --export-format json --output $(dirname /tmp/scan)/$(basename /tmp/scan).json` and `jq '.findings[] | {findingId, ruleId, severity: .severity.level}'` summary.
- Upload: `gh api --method POST -H "Accept: application/vnd.github+json" /repos/[OWNER]/[REPO]/code-scanning/sarifs -f sarif=@$(dirname /tmp/scan)/$(basename /tmp/scan).sarif -f ref=refs/heads/main` OR use `actions/upload-sarif` in CI and show YAML snippet.
- Verify fingerprints: `jq '.runs[0].results[0].partialFingerprints["codexSecurity/v1"]' $(dirname /tmp/scan)/$(basename /tmp/scan).sarif`
- Do NOT use deprecated `--scan-dir/--format` — use positional scanDir + --export-format.
````

**Under the hood:** `export --export-format sarif/json/csv --source-root` + GitHub SARIF API.
**Non-obvious:** `--source-root` produces correct line fingerprints; output inside scanDir is forbidden since 0.1.20.

### 10. Pre-Commit Hook + Working-Tree Fallback

**When:** Block commits locally.

**Prompt:**
````markdown
Pre-commit security gate for [REPO=. ]:

- `npx @openai/codex-security install-hook . --fail-on-severity high` — install Git hook.
- Test hook: `npx @openai/codex-security scan . --working-tree --output-dir /tmp/hook-test --headless --fail-on-severity high`
- If hook blocks, show `findings list --format json | jq '.findings[] | {occ: .occurrenceId, title}'` and triage: `npx @openai/codex-security findings false-positive occ_... --reason "Validated by Zod at src/middleware/validate.ts:42 — rejects ../ and absolute paths"` with evidence line.
- Explain `OutputDirectoryError/OutputDirectoryNotEmptyError` vs `OutputInsideProtectedRootError` and fix via `--archive-existing`.
````

**Under the hood:** `install-hook` + `scan --working-tree` + `findings false-positive`.
**Non-obvious:** `working-tree` scans staged+unstaged vs `HEAD`; triage persists by fingerprint so re-scan suppresses.

### 11. SDK Orchestration (Preflight → Run → Cost → Publish)

**When:** Build pipeline, need programmatic control.

**Prompt:**
````markdown
Write TypeScript at examples/sdk_orchestrate.ts that:

- `const security = new CodexSecurity({codexOverrides:{model_reasoning_effort:"xhigh"}})` with `await using` or `try{...}finally{await security.close()}`.
- Preflight: `await security.preflight(repo,{mode:"standard", outputDir:"/tmp/sdk-preflight"})` — log `model/reasoningEffort/authentication` and abort on OutputDirectoryNotEmptyError with archiveExisting.
- Run: `await security.run(repo,{outputDir:"/tmp/sdk-run", mode:"standard", maxCostUsd:10, knowledgeBasePaths:["docs/security/threat_model.md"], onCost:(c)=>console.log(c.totalUsd), onWorkerStatus, onProgress, onSessionEvent, signal: AbortSignal.timeout(30*60e3)})`
- Handle `ScanCostLimitExceededError` (log cost.totalUsd + scanDir) and `ConfigurationError`.
- After: `for(const f of result.findings.findings) console.log(f.severity.level, f.ruleId, f.locations[0])` with canonical schema (severity object, not string).
- Cost: `estimateScanCost(sessionEvents)` and log `inputTokens/outputTokens/totalUsd`.
- Optional: `await checkScanPublication("/tmp/sdk-run",{destination:"linear",teamId})` then `await publishScan(...)` with dryRun first.
- Show `npx tsc --skipLibCheck` passes and `npx @openai/codex-security export /tmp/sdk-run --export-format json --output /tmp/sdk.json` post-process.
````

**Under the hood:** `CodexSecurity` SDK + `ScanCostTracker` + `publishScan`.
**Non-obvious:** SDK `preflight` returns struct, not `{ready,issues}`; `run` throws typed errors — catch `OutputDirectoryNotEmptyError/ScanCostLimitExceededError` specifically.

### 12. Coverage Gap Analysis (What Wasn't Scanned)

**When:** Prove completeness to auditor.

**Prompt:**
````markdown
Coverage gap analysis for latest scan in [REPO=. ]:

- `npx @openai/codex-security scans list . --format json | jq '.scans[0]'` — get latest scanId.
- `npx @openai/codex-security scans show <scanId> --show-linked-findings --format json > /tmp/show.json && jq '.scan.coverage, .scan.scope' /tmp/show.json`
- Read `/tmp/scan/coverage.json` directly: report `completeness` (complete/partial/unknown), `surfaces[]` dispositions `reported/no_issue_found/rejected/not_applicable/needs_follow_up`, `deferred[]` with reasons, `explicitExclusions[]`, `openQuestions[]`.
- Correlate with `scan-manifest.json` `scope.artifactsReviewed` and `scope.limitations`.
- Suggest next scan: `--path` for uncovered dirs, or `--knowledge-base` for missing threat model, or `--mode deep` if `needs_follow_up` >0.
````

**Under the hood:** `scans show/list/logs` + `coverage.json` + `scan-manifest.json`.
**Non-obvious:** Coverage is first-class artifact — `needs_follow_up` surfaces explain why deep mode is needed.

---

### Prompt Engineering Tips for This Skill
- **Knowledge base is repeatable** — pass every `threat_model.md`, `architecture.md`, and `.agents/memory/*.md` you have; the model fuses them.
- **Always sibling SARIF** — never `scanDir/results.sarif`; use `$(dirname scanDir)/$(basename scanDir).sarif` or outside path.
- **Dry-run first in CI** — `scan --dry-run` costs $0 and catches `clean checkout` or `output inside repo` errors.
- **Headless in automation** — `scan --headless` disables Ink dashboard; required for `scripts/run_security_scan.sh` in CI.
- **Cost guards** — `--max-cost 10.00` throws `ScanCostLimitExceededError` — catch and `checkScanPublication` before retry.
- **Auth precedence** — `OPENAI_API_KEY` > `CODEX_API_KEY` > `OPENROUTER_API_KEY` (+ `--provider openrouter`) > `AWS_BEARER_TOKEN_BEDROCK` > stored `login`. Use `info` to verify.

## TypeScript SDK Usage

```ts
import { CodexSecurity } from "@openai/codex-security";

const security = new CodexSecurity({
  codexOverrides: { model_reasoning_effort: "xhigh" }, // default is xhigh, gpt-5.6-sol
});

try {
  // Optional preflight without spending:
  // const preflight = await security.preflight("/path/to/repository", { outputDir: "/tmp/results" });
  const result = await security.run("/path/to/repository", {
    outputDir: "/tmp/results", // must be outside repo; chmod 700
    mode: "standard",
    maxCostUsd: 10.0,
    onWorkerStatus: (status) => {
      console.log(`Worker ${status.workerNumber}: ${status.phase}`);
    },
    onProgress: (p) => console.log(`${p.phase} ${p.filesCompleted}/${p.filesTotal}`),
  });

  console.log(`Scan ID: ${result.scanId}`);
  console.log(`Report: ${result.reportPath}`);
  console.log(`Findings: ${result.findings.findings.length}`);
  for (const f of result.findings.findings) {
    console.log(`- [${f.severity.level}] ${f.title} at ${f.locations[0]?.path}:${f.locations[0]?.startLine}`);
  }
} finally {
  await security.close();
}
```

---

## Technical References

- [CLI Reference](references/cli-reference.md): Complete list of commands, flags, inference providers, and exit codes.
- [TypeScript SDK Reference](references/sdk-reference.md): SDK classes, methods, events, and configuration options.
- [Finding Schema](references/finding-schema.md): Data structure for findings, severity levels, and dispositions.
- [Validation Rubric](references/validation-rubric.md): Rules for evidence hierarchy, dynamic validation, and static analysis.
- [Threat Modeling](references/threat-modeling.md): STRIDE model, boundary analysis, and attack path procedures.
- [Remediation and Patch Risk](references/remediation-and-patch-risk.md): Patch creation rules, regression test requirements, and risk metrics.

---

## License

This project is licensed under the [MIT License](LICENSE).
