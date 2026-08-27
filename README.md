# OpenAI Codex Security Skill

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Agent Skill](https://img.shields.io/badge/Agent_Skill-Universal-purple.svg)](#-agent-compatibility--installation)
[![npm package](https://img.shields.io/badge/npm-%40openai%2Fcodex--security-red)](https://www.npmjs.com/package/@openai/codex-security)

A universal, production-ready AI agent skill and workflow toolkit for **[OpenAI Codex Security](https://github.com/openai/codex-security)**.

This skill equips any AI coding agent, autonomous assistant, or CI/CD workflow with automated vulnerability discovery, deep multi-worker audits, PR diff scanning, evidence-backed finding validation, automated patch remediation, risk assessment, false-positive triage, and SARIF/JSON/CSV exports.

---

## 🤖 Agent Compatibility & Installation

This skill follows the standard **Agent Skill Protocol** (`SKILL.md` with structured YAML frontmatter and progressive disclosure references) and is compatible with any AI coding agent or IDE environment:

| Agent / Environment | Skill Directory Path |
| :--- | :--- |
| **Universal Agent Standard** | `.agents/skills/codex-security/` |
| **Claude Code** | `.claude/skills/codex-security/` or `~/.claude/skills/` |
| **Cursor / Windsurf / Cline / Roo** | `.agents/skills/codex-security/` or project root |
| **Antigravity (AGY)** | `.agents/skills/codex-security/` or `~/.gemini/config/skills/` |
| **Global User Configuration** | `~/.agents/skills/codex-security/` |

### Installation Options

#### 1. Workspace Level (Project-Specific)
Clone or copy into your project's agent skills directory:

```bash
# Standard universal agent directory:
mkdir -p .agents/skills
git clone https://github.com/Dreamstick9/codex-security-skill.git .agents/skills/codex-security

# Or for Claude Code:
mkdir -p .claude/skills
git clone https://github.com/Dreamstick9/codex-security-skill.git .claude/skills/codex-security
```

#### 2. Global Installation (Available Across All Projects)
Clone into your global user skills home:

```bash
mkdir -p ~/.agents/skills
git clone https://github.com/Dreamstick9/codex-security-skill.git ~/.agents/skills/codex-security
```

---

## 📦 What's Included

```text
codex-security-skill/
├── SKILL.md                          # Master agent skill runbook with YAML frontmatter
├── references/
│   ├── cli-reference.md              # Complete CLI syntax, flags, providers & exit codes
│   ├── sdk-reference.md              # TypeScript SDK API, classes, methods & types
│   ├── finding-schema.md             # Standardized vulnerability finding JSON schema
│   ├── validation-rubric.md          # PoC generation, test adaptation & FP dismissal
│   ├── threat-modeling.md            # STRIDE threat modeling & attack path analysis
│   └── remediation-and-patch-risk.md # Automated patch synthesis & risk assessment
├── examples/
│   ├── cli_recipes.sh                # Practical shell cookbook for CI/CD, PRs & audits
│   ├── sdk_scan_example.ts           # Programmatic scan example with event streaming
│   ├── sdk_github_validation.ts      # GitHub Code Scanning alert validation script
│   └── components_plan.json          # Monorepo multi-component scan configuration
└── scripts/
    ├── run_security_scan.sh          # Isolated scan runner wrapper
    ├── export_sarif.sh               # SARIF report exporter
    └── triage_false_positive.sh      # False-positive triage helper
```

---

## ⚡ Quick Start

### Prerequisites
- Node.js 22.13.0+
- Python 3.10+
- OpenAI API Key (`OPENAI_API_KEY`) or ChatGPT account

### Authentication
```bash
# Interactive login
npx @openai/codex-security login

# Headless / remote device authentication
npx @openai/codex-security login --device-auth

# Or via API key
export OPENAI_API_KEY="sk-..."
```

### 1. Run a Standard Repository Scan
```bash
# Using the helper script
./scripts/run_security_scan.sh /path/to/project

# Or directly via CLI
npx @openai/codex-security scan /path/to/project \
  --output-dir /tmp/scan-results \
  --fail-on-severity high
```

### 2. Run a PR / Diff Scan
```bash
# Scan committed changes against base branch
npx @openai/codex-security scan /path/to/project \
  --diff origin/main \
  --output-dir /tmp/pr-scan-results

# Or scan uncommitted working tree changes
npx @openai/codex-security scan /path/to/project \
  --working-tree \
  --output-dir /tmp/working-tree-scan
```

### 3. Deep Multi-Worker Audit
```bash
npx @openai/codex-security scan /path/to/project \
  --mode deep \
  --workers 4 \
  --subagents 2 \
  --max-cost 20.00 \
  --max-time-hours 12 \
  --output-dir /tmp/deep-scan-results
```

### 4. Monorepo Multi-Component Scan
```bash
# Generate plan
npx @openai/codex-security scan-components /path/to/project --auto --plan-only --output-dir /tmp/plan

# Run scan across all components
npx @openai/codex-security scan-components /path/to/project \
  --components-file /tmp/plan/components.json \
  --workers 4 \
  --output-dir /tmp/component-results
```

### 5. Automated Patching & Draft PR
```bash
npx @openai/codex-security scan /path/to/project \
  --patch \
  --patch-severity high \
  --create-pr \
  --output-dir /tmp/remediation-results
```

---

## 🛠️ TypeScript SDK Usage

```ts
import { CodexSecurity } from "@openai/codex-security";

const security = new CodexSecurity({
  codexOverrides: { model_reasoning_effort: "high" },
});

try {
  const result = await security.run("/path/to/repository", {
    outputDir: "/tmp/results",
    mode: "standard",
    maxCostUsd: 10.0,
    onWorkerStatus: (status) => console.log(`Worker ${status.workerNumber}: ${status.phase}`),
  });

  console.log(`Scan ID: ${result.scanId}`);
  console.log(`Report: ${result.reportPath}`);
  console.log(`Findings: ${result.findings.findings.length}`);
} finally {
  await security.close();
}
```

---

## 📚 Documentation & References

- [CLI Reference](references/cli-reference.md) — Comprehensive commands, flags, inference providers, and exit codes.
- [TypeScript SDK Reference](references/sdk-reference.md) — Client methods, component scans, GitHub alert validation, cost estimation.
- [Finding Schema & Taxonomy](references/finding-schema.md) — Structured finding format, severity levels, and validation dispositions.
- [Validation Rubric & Proof Methods](references/validation-rubric.md) — Hierarchy of evidence: crash PoCs, test harnesses, and static proofs.
- [Threat Modeling Guide](references/threat-modeling.md) — STRIDE analysis, trust boundaries, and attack paths.
- [Remediation & Patch Risk Analysis](references/remediation-and-patch-risk.md) — Surgical patching, regression tests, and risk assessment rubrics.

---

## 📄 License

[MIT](LICENSE)
