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
