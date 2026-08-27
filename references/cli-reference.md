# Codex Security CLI Reference

Version: `@openai/codex-security@0.1.20` (Codex 0.148.0-alpha.8, plugin 0.1.37). Verified against `npx @openai/codex-security --help` and per-command `--help`.

## Invocation

```bash
# Run without install (recommended):
npx @openai/codex-security <command> [options]

# Or install globally:
npm install -g @openai/codex-security
codex-security <command> [options]

# Inspect help / version / LLM manifest:
npx @openai/codex-security --help
npx @openai/codex-security --version
npx @openai/codex-security <command> --help
npx @openai/codex-security --llms-full
```

Binary entry point is `codex-security`. `npx @openai/codex-security` is an alias. All flags use kebab-case on the CLI and camelCase in the `--llms-full` JSON manifest (e.g. `--output-dir` ↔ `outputDir`).

---

## Global Options

Applied to every command. Output filtering is orthogonal to scan output dir.

| Option | Type | Description |
| :--- | :--- | :--- |
| `--help` | boolean | Show command help. |
| `--version` | boolean | Print package / plugin versions. Use `npx @openai/codex-security info` for full metadata. |
| `--format <toon|json|yaml|md|jsonl>` | string | Machine-readable output format for the CLI envelope (not the scan artifact format). |
| `--filter-output <keys>` | string | Filter output envelope by key paths (`a,b.c,d[0,3]`). |
| `--full-output` | boolean | Show full output envelope including metadata. |
| `--token-count` / `--token-limit <n>` / `--token-offset <n>` | int | Token accounting helpers. |
| `--schema` | boolean | Print JSON Schema for the command. |
| `--llms` / `--llms-full` | boolean | Print LLM-readable manifest of all commands. |
| `--mcp` | boolean | Start as MCP stdio server. |

Exit-code contract (consistent across commands):

| Code | Meaning |
| :--- | :--- |
| `0` | Success. For `scan`: no findings exceeded `--fail-on-severity` (or flag not set). |
| `1` | Scan completed but findings tripped `--fail-on-severity`; or command-specific failure. |
| `2` | Invalid arguments, missing dependencies, or execution error. |
| `130` | Interrupted by `SIGINT` (Ctrl+C). |
| `143` | Terminated by `SIGTERM`. |

Environment isolation: CLI stores creds in `CODEX_SECURITY_STATE_DIR` (default: platform-specific Codex home). Keep `--output-dir` **outside** the target repository and `chmod 700`.

---

## 1. `scan [repository]`

Run a security scan on a repository or the current directory.

```bash
npx @openai/codex-security scan [repository] [options]
```

### Arguments
- `repository` – Repository root to scan. Defaults to `.` (current directory).

### Target selection

| Flag | Type | Description |
| :--- | :--- | :--- |
| `--path <array>` | string[] | Scan only this repo-relative path; repeat for multiple paths (`--path src/auth --path src/api`). |
| `--diff <string>` | string | Scan committed changes from `BASE` to `--head` (default `HEAD`). Example: `--diff origin/main`. |
| `--working-tree` | boolean | Scan staged + unstaged changes against `--base` (default `HEAD`). |
| `--head <string>` | string | Head ref for `--diff`. |
| `--base <string>` | string | Base ref for `--working-tree`. |

Diff and working-tree modes reuse the same manifest/coverage pipeline but limit `includePaths` to changed files (see `_bundled_plugin/references/scan-contract.md`).

### Scan modes & resource limits

| Flag | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `--mode <standard|deep>` | string | `standard` | `standard` = single-pass audit; `deep` = multi-pass concurrent audit with worker subagents. Deep supports repo + path targets. |
| `--workers <number>` | int | – | Max concurrent deep discovery workers. |
| `--subagents <number>` | int | – | Subagents per deep worker. |
| `--stop-after-no-new <number>` | int | – | Stop deep after N runs with no new issues. |
| `--max-discovery-runs <number>` | int | – | Maximum deep discovery runs. |
| `--max-time-hours <number>` | number | `96` (max 96) | Maximum deep discovery hours. |
| `--max-cost <number>` | number | – | Stop when estimated USD cost exceeds amount. Emits `ScanCostLimitExceededError`. |

### Context & knowledge base

| Flag | Type | Description |
| :--- | :--- | :--- |
| `--knowledge-base <array>` | string[] | Security-context files/dirs; repeat flag. Candidate for `--threat-model` content. |
| `--scan-prompt-file <string>` | string | Append scan instructions from file (discovery + validation). |
| `--validation-prompt-file <string>` | string | Replace final validation workflow (not Deep). |
| `--post-scan-prompt-file <string>` | string | Run after each scan, including failures. |

### Output & gating

| Flag | Type | Description |
| :--- | :--- | :--- |
| `--output-dir <string>` | string | Artifact directory **outside** repo. Default: Codex Security state dir. Must be empty; use `--archive-existing` to archive. |
| `--archive-existing` | boolean | Archive existing results in `--output-dir`; requires `--output-dir`. |
| `--fail-on-severity <critical|high|medium|low>` | string | Exit `1` if findings at or above level. |
| `--verbose` | boolean | Diagnostics to stderr. |
| `--headless` | boolean | Plain-text progress instead of dashboard (CI-safe). |
| `--dry-run` | boolean | Validate inputs without starting a scan. Use in CI preflight. |

### Remediation & patching (scan-inline)

| Flag | Type | Description |
| :--- | :--- | :--- |
| `--patch` | boolean | Patch + verify confirmed findings after scan. |
| `--patch-severity <critical|high|medium|low>` | string | Minimum level to patch; requires `--patch`. |
| `--create-pr` | boolean | Create draft GitHub PR after verified patches (requires `gh` auth). |

For standalone patching see `patch` and `verify-fix` commands.

### Model / provider / auth

| Flag | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `--provider <openai|openrouter|fireworks|amazon-bedrock>` | string | `openai` | Inference provider. |
| `--model <string>` | string | `gpt-5.6-sol` | OpenAI model id. |
| `--effort <minimal|low|medium|high|xhigh|max>` | string | `xhigh` | Reasoning effort. |
| `--auth <auto|chatgpt|api-key>` | string | `auto` | Credential source. `auto` tries ChatGPT session then API keys. |
| `--safety-identifier <string>` | string | – | 1–64 char stable hashed end-user ID for request logging. |
| `--codex <array>` | string[] | – | TOML overrides (`model_reasoning_effort="high"`). Repeat. |
| `--plugin-path <string>` | string | bundled | Plugin dir or ZIP. |
| `--python <string>` | string | auto | Python 3.10+ interpreter (`PYTHON` env or auto-discovered). |

### Examples

```bash
# Standard scan with gating
npx @openai/codex-security scan . --output-dir /tmp/scan --fail-on-severity high --headless

# Diff scan for PRs
npx @openai/codex-security scan . --diff origin/main --output-dir /tmp/pr-scan

# Working-tree pre-commit
npx @openai/codex-security scan . --working-tree --output-dir /tmp/wt-scan

# Deep audit with budgets
npx @openai/codex-security scan . --mode deep --workers 4 --subagents 2 --max-cost 20 --max-time-hours 6 --stop-after-no-new 2 --output-dir /tmp/deep

# Scoped + threat model
npx @openai/codex-security scan . --path src/auth --path src/middleware --knowledge-base docs/security/threat_model.md --output-dir /tmp/scoped

# Dry-run validation in CI
npx @openai/codex-security scan . --dry-run

# Patch inline
npx @openai/codex-security scan . --patch --patch-severity high --create-pr --output-dir /tmp/remed
```

---

## 2. `scan-components [repository]`

Split large repos into components and scan each separately (standard mode per component + deduplication).

```bash
npx @openai/codex-security scan-components [repository] [options]
```

### Options

| Flag | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `--component <array>` | string[] | – | Repo-relative path as a component; repeat. |
| `--components-file <string>` | string | – | Read plan from JSON (written by `--plan-only`). |
| `--auto` | boolean | `false` | Ask Codex to divide project into components. |
| `--plan-only` | boolean | `false` | Write `components.json` without scanning. |
| `--headless` | boolean | `false` | Status lines instead of dashboard. |
| `--output-dir <string>` | string | – | **Required** unless `--plan-only`. Must be outside repo & empty. |
| `--workers <number>` | int | `4` | Concurrent component scans. |
| `--knowledge-base <array>` | string[] | – | Shared security docs for every component. |
| `--scan-prompt-file <string>` | string | – | Append to every scan. |
| `--post-scan-prompt-file <string>` | string | – | Run after each component scan. |
| `--model <string>` | string | – | Model for planning + scans (default `gpt-5.6-sol`). |
| `--effort <minimal|low|medium|high|xhigh|max>` | string | `xhigh` | |
| `--provider <openai|openrouter|fireworks|amazon-bedrock>` | string | `openai` | |
| `--max-cost <number>` | number | – | Per-component cost cap. |
| `--auth <auto|chatgpt|api-key>` | string | `auto` | |
| `--plugin-path <string>` | string | bundled | |
| `--python <string>` | string | auto | |
| `--codex <array>` | string[] | – | TOML overrides. |

### Recipes

```bash
# Auto-plan then run
npx @openai/codex-security scan-components . --auto --plan-only --output-dir /tmp/plan
cat /tmp/plan/components.json
npx @openai/codex-security scan-components . --components-file /tmp/plan/components.json --workers 4 --output-dir /tmp/comp-results --headless

# Explicit components
npx @openai/codex-security scan-components . --component apps/web --component apps/api --output-dir /tmp/comp-results
```

Plan schema: `{"components":[{"name":"...","paths":["apps/web"]}]}` – see `examples/components_plan.json`.

---

## 3. `findings`

Manage saved findings across scans.

```bash
npx @openai/codex-security findings <command> [options]
```

### `findings list [repository]`
List open findings for a repository (default `.`). No extra flags; filter output with `--format json --filter-output findings`.

```bash
npx @openai/codex-security findings list .
npx @openai/codex-security findings list . --format json --filter-output findings
```

### `findings false-positive <occurrenceId> --reason <string>`
Mark a finding as false positive for future scans (persisted to workbench DB). `occurrenceId` format is `occ_[a-f0-9]{24}`.

```bash
npx @openai/codex-security findings false-positive occ_abc123... --reason "Validated by API gateway Zod schema; payload rejected before sink."
```

---

## 4. `scans`

Inspect previous scan records, costs, and logs.

```bash
npx @openai/codex-security scans <command>
```

| Subcommand | Usage | Description |
| :--- | :--- | :--- |
| `list [repository]` | `scans list [repo] [--scan-root <dir>]` | List saved scans. `--scan-root` includes scans under a custom output root. |
| `show [scanId]` | `scans show [scanId] [--show-linked-findings]` | Show manifest + results + config. `scanId` is `id` or unique prefix; default latest completed. |
| `logs [scanId]` | `scans logs [scanId]` | Stream saved activity for a scan + its workers. |
| `rerun [scanId]` | `scans rerun [scanId] [--validation-prompt-file <file>] [--verbose]` | Rerun saved scan with original config. |
| `compare [beforeId] [afterId]` | `scans compare [beforeId] [afterId]` | Match + compare findings/coverage between two scans. |
| `match [beforeId] [afterId]` | `scans match [--all] [--force] [beforeId] [afterId]` | Match findings by root cause. `--all` matches all completed scans. |

Examples:
```bash
npx @openai/codex-security scans list .
npx @openai/codex-security scans show --show-linked-findings
npx @openai/codex-security scans logs <scanId>
npx @openai/codex-security scans compare <beforeId> <afterId>
```

---

## 5. `export [scanDir]`

Export findings from a completed scan as SARIF / JSON / CSV.

```bash
npx @openai/codex-security export [scanDir] --export-format <sarif|json|csv> --output <file|-> [--source-root <dir>]
```

| Arg / Flag | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `scanDir` (positional) | string | latest completed | Completed scan directory. |
| `--export-format <csv|json|sarif>` | string | `sarif` | Artifact format. |
| `--output <string>` | string | `results.sarif` / `findings.json` / `findings.csv` | File or `-` for stdout. |
| `--source-root <string>` | string | – | Checkout path for SARIF fingerprints. |
| `--python <string>` | string | auto | Python for bundled SARIF adapter. |

**Breaking change vs. old docs:** flags were previously documented as `--scan-dir` / `--format`; the real flags are `scanDir` positional and `--export-format`. Aliases do **not** exist.

```bash
# SARIF for GitHub Code Scanning
npx @openai/codex-security export /tmp/scan --export-format sarif --output results.sarif --source-root .

# JSON/CSV to stdout
npx @openai/codex-security export --export-format json --output -
npx @openai/codex-security export --export-format csv --output findings.csv
```

---

## 6. `login` / `logout`

Manage authentication.

```bash
npx @openai/codex-security login [status] [--device-auth] [--with-api-key] [--with-access-token]
npx @openai/codex-security logout
```

- `login` – Interactive ChatGPT browser login.
- `login --device-auth` – Device-code flow (headless/CI).
- `login --with-api-key` – Read API key from stdin: `printenv OPENAI_API_KEY | npx @openai/codex-security login --with-api-key`
- `login --with-access-token` – Read access token from stdin.
- `login status` – Show stored auth state.
- `logout` – Remove stored sign-in. Env vars (`OPENAI_API_KEY`, `CODEX_API_KEY`, `OPENROUTER_API_KEY`, `AWS_*`) still work without login.

Env precedence for `scan`:
`OPENAI_API_KEY` / `CODEX_API_KEY` > `OPENROUTER_API_KEY` (with `--provider openrouter`) > `AWS_BEARER_TOKEN_BEDROCK` (with `--provider amazon-bedrock`) > stored `login` credentials > error.

---

## 7. `patch` / `verify-fix` / `validate`

Post-scan remediation. These run the Codex fix/verify pipeline without re-discovering.

### `patch [issues...]`
Patch one or more issues and verify.

```bash
npx @openai/codex-security patch [issues...] [options]
```

| Flag | Type | Description |
| :--- | :--- | :--- |
| `issues...` | string[] | Issue text or file containing issues. |
| `--scan <string>` | string | Patch open findings from a saved scan id/prefix. |
| `--severity <critical|high|medium|low>` | string | Patch findings ≥ level. |
| `--linear-issue <array>` | string[] | Linear issue id/URL; repeat. |
| `--linear-project <string>` | string | Patch every open issue in a Linear project. |
| `--linear-filter <string>` | string | JSON Linear filter for `--linear-project`. |
| `--linear-api-key <string>` | string | Defaults to `CODEX_SECURITY_LINEAR_API_KEY`. |
| `--effort <minimal|low|medium|high|xhigh|max>` | string | Reasoning effort. |
| `--create-pr` | boolean | Draft GitHub PR after verified patches. |
| `--resume-pr <string>` | string | Resume publication of saved patch branch. |
| `--codex <array>` | string[] | TOML overrides (model/effort only). |

### `verify-fix [findings...]`
Verify fixes exist without mutating the repo.

```bash
npx @openai/codex-security verify-fix [findings...] [--scan <id>] [--severity <lvl>] [--linear-*]
```

Same Linear / `--scan` / `--severity` / `--effort` / `--codex` flags as `patch`.

### `validate <findings...>`
Validate candidate findings (SDK backing is `security.validate`).

```bash
npx @openai/codex-security validate <findings...> [--effort <lvl>] [--codex <kv>]
```

`findings...` is text or file. Returns `reportable|suppressed|not_applicable|deferred` per entry.

### `bulk-scan [input]`
Discover repositories and run resumable bulk scans.

```bash
npx @openai/codex-security bulk-scan [input] --output-dir <dir> [options]
```

`input` is a CSV repository list; omit to discover interactively. Retries per repo via `--max-attempts`. See `npx @openai/codex-security bulk-scan --help`.

---

## 8. `publish`

Push findings to issue trackers (Linear).

```bash
npx @openai/codex-security publish <command> [options]
```

| Subcommand | Description |
| :--- | :--- |
| `publish scan [scanDir]` | Publish every finding from a completed scan to Linear. |
| `publish check <scanDir>` | Check scan history + Linear access without creating issues. |

Common flags: `--to linear`, `--linear-team <id>` (`CODEX_SECURITY_LINEAR_TEAM`), `--linear-project <id>` (`CODEX_SECURITY_LINEAR_PROJECT`), `--linear-api-key <string>` (`CODEX_SECURITY_LINEAR_API_KEY`), `--linear-assignee <email|id>`, `--dry-run`, `--skip-existing`. The old flag `--to` / `--linear-team` / `--project` (deprecated alias for `--linear-project`) are still parsed via the publish SDK (`publishScan`).

---

## 9. `install-hook` / `info` / `skills` / `completions` / `mcp`

| Command | Usage | Description |
| :--- | :--- | :--- |
| `install-hook [repository]` | `install-hook [repo] [--fail-on-severity <lvl>]` | Install Git pre-commit hook that scans staged changes. Default `high`. |
| `info` | `info` | Read-only SDK/plugin metadata: `sdkVersion`, `bundledPluginVersion`, `cliVersion`, `codexVersion`, `model`, `reasoningEffort`. |
| `skills` | `skills add/list` | Sync skill files to agents. |
| `completions` | `completions <shell>` | Shell completion script. |
| `mcp` | `mcp add/doctor` | Register as MCP server. |

---

## Exit-code & CI patterns

```bash
# Gate PR: fail on high+
npx @openai/codex-security scan . --diff origin/main --output-dir /tmp/pr --fail-on-severity high --headless
# Capture exit code without failing step:
SCAN_EC=$?
if [ $SCAN_EC -eq 1 ]; then echo "Security gate tripped"; fi
if [ $SCAN_EC -eq 2 ]; then echo "Scan error"; exit 2; fi

# Preflight without spending
npx @openai/codex-security scan . --dry-run

# Headless deep with cost guard
npx @openai/codex-security scan . --mode deep --workers 4 --max-cost 25 --headless --output-dir /tmp/deep
```
