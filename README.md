# OpenAI Codex Security Skill for Antigravity (AGY)

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Antigravity Skill](https://img.shields.io/badge/Antigravity-Skill-green.svg)](https://antigravity.google)
[![npm package](https://img.shields.io/badge/npm-%40openai%2Fcodex--security-red)](https://www.npmjs.com/package/@openai/codex-security)

A fully-fledged **Antigravity (AGY)** skill for **[OpenAI Codex Security](https://github.com/openai/codex-security)**.

This skill equips Antigravity AI agents with automated vulnerability discovery, deep multi-worker audits, PR diff scanning, evidence-backed finding validation, automated patch remediation, risk assessment, false-positive triage, and SARIF/JSON/CSV exports.

---

## 📦 What's Included

```text
codex-security-skill/
├── SKILL.md                          # Master skill runbook with YAML frontmatter
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

## 🚀 Installation into Antigravity (AGY)

### 1. Workspace Level (Project-Specific)
Clone or copy this repository into your project's `.agents/skills/codex-security/` directory:

```bash
mkdir -p .agents/skills
git clone https://github.com/Dreamstick9/codex-security-skill.git .agents/skills/codex-security
```

### 2. Global Level (All Projects)
Clone into your global Antigravity configuration directory:

```bash
mkdir -p ~/.gemini/config/skills/
git clone https://github.com/Dreamstick9/codex-security-skill.git ~/.gemini/config/skills/codex-security
```

Antigravity will automatically discover and mount the skill via progressive disclosure.

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

# Or via API key
export OPENAI_API_KEY="sk-..."
```

### Run a Standard Scan
```bash
# Using the helper script
./scripts/run_security_scan.sh /path/to/project

# Or directly via CLI
npx @openai/codex-security scan /path/to/project \
  --output-dir /tmp/scan-results \
  --fail-on-severity high
```

### Run a PR Diff Scan
```bash
npx @openai/codex-security scan /path/to/project \
  --diff origin/main \
  --output-dir /tmp/pr-scan-results
```

### Deep Multi-Worker Audit
```bash
npx @openai/codex-security scan /path/to/project \
  --mode deep \
  --workers 4 \
  --subagents 2 \
  --max-cost 20.00 \
  --output-dir /tmp/deep-scan-results
```

### Automated Patching & Draft PR
```bash
npx @openai/codex-security scan /path/to/project \
  --patch \
  --patch-severity high \
  --create-pr \
  --output-dir /tmp/remediation-results
```

---

## 📚 Documentation & References

- [CLI Reference](references/cli-reference.md)
- [TypeScript SDK Reference](references/sdk-reference.md)
- [Finding Schema & Taxonomy](references/finding-schema.md)
- [Validation Rubric & Proof Methods](references/validation-rubric.md)
- [Threat Modeling Guide](references/threat-modeling.md)
- [Remediation & Patch Risk Analysis](references/remediation-and-patch-risk.md)

---

## 📄 License

[MIT](LICENSE)
