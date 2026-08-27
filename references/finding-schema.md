# Finding Schema and Vulnerability Taxonomy

Verified against `_bundled_plugin/schemas/findings.schema.json`, `dist/models.d.ts`, and `examples/completed-scan/findings.json` for `@openai/codex-security@0.1.20`.

Codex Security findings are **not** the simplified `Finding` from older skill drafts. Every record in `findings.json` is a `FindingsDocument["findings"][number]` with 11 required top-level keys and typed sub-objects.

---

## Severity Levels

`FindingSeverity.level` enum (from schema). Use with `--fail-on-severity`, `--patch-severity`, `--severity`.

| Severity | Meaning | Typical Examples |
| :--- | :--- | :--- |
| `critical` | Remote exploit, no auth, arbitrary code / data loss | RCE, auth bypass, SSRF → cloud metadata |
| `high` | Minimal auth/interaction, private data or privilege escalation | IDOR, stored XSS, exposed prod secret |
| `medium` | Non-standard preconditions or specific config | CSRF, reflected XSS, weak crypto |
| `low` | Defense-in-depth / info leak | Stack traces in responses, missing sec headers, insecure cookie flags |
| `informational` | Hardening suggestion, not directly exploitable | Deprecated crypto in non-sec context, redundant validation |

Each severity is an **object**, not a string:

```json
"severity": {
  "level": "critical",
  "score": 9.8,
  "scoringSystem": "CVSS:3.1",
  "vector": "CVSS:3.1/AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:H/A:H",
  "rationale": "...",
  "changeConditions": "..."
}
```

Only `level` is required; other fields are optional and informational.

---

## Confidence Levels

Every finding carries a calibrated `confidence` object:

```json
"confidence": { "level": "high", "rationale": "Reproduced with concrete sink trace; payload reached db.raw without sanitizer." }
```

Enum for `confidence.level`: `high` | `medium` | `low`.

---

## FindingsDocument Envelope

`findings.json` top-level:

```json
{
  "documentType": "codex-security.findings",
  "schemaVersion": "1.0",
  "scanId": "01H... or uuid",
  "findings": [ Finding, Finding, ... ]
}
```

---

## Finding JSON Structure

Required keys on every `Finding` (9 required + 2 conditional):

`findingId`, `occurrenceId`, `ruleId`, `identity`, `fingerprints`, `title`, `summary`, `severity`, `confidence`, `taxonomy`, `locations`, `remediation`, `provenance`.

Full shape (prettier-printed from schema + real example):

```json
{
  "findingId": "csf_a1b2c3d4e5f6a7b8c9d0e1f2",
  "occurrenceId": "occ_a1b2c3d4e5f6a7b8c9d0e1f2",
  "ruleId": "sql-injection.raw-query",
  "identity": {
    "anchor": "sql-injection.raw-query",
    "instance": "sql-injection.raw-query.src/controllers/userController.ts"
  },
  "fingerprints": {
    "algorithm": "codex-security/v1",
    "primary": "codex-security/v1:sha256:9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2..."
  },
  "title": "SQL Injection in User Profile Lookup",
  "summary": "User input from req.params.id is concatenated into raw SQL without binding.",
  "severity": {
    "level": "critical",
    "rationale": "Unauthenticated endpoint, direct DB exfiltration possible."
  },
  "confidence": {
    "level": "high",
    "rationale": "Sink db.raw reached from req.params.id with no parameterization; validation probe confirmed not sanitized."
  },
  "taxonomy": {
    "category": "Improper Neutralization of Special Elements used in an SQL Command",
    "cwe": ["CWE-89"]
  },
  "locations": [
    {
      "path": "src/controllers/userController.ts",
      "startLine": 45,
      "endLine": 48,
      "role": "sink"
    },
    {
      "path": "src/routes/users.ts",
      "startLine": 12,
      "role": "source"
    }
  ],
  "codeEvidence": [
    {
      "id": "evidence-1",
      "label": "Vulnerable sink",
      "path": "src/controllers/userController.ts",
      "startLine": 45,
      "endLine": 48,
      "language": "typescript",
      "role": "sink",
      "code": "const user = await db.raw(`SELECT * FROM users WHERE id = '${req.params.id}'`);",
      "explanation": "String interpolation into raw SQL; req.params.id flows unsanitized."
    }
  ],
  "rootCause": {
    "summary": "String interpolation in raw SQL instead of parameterized placeholders.",
    "evidenceRefs": ["evidence-1"],
    "code": "db.raw(`SELECT * FROM users WHERE id = '${req.params.id}'`)",
    "language": "typescript"
  },
  "remediation": "Use parameterized bindings: `db('users').where({ id: req.params.id }).first()` or `db.raw('SELECT * FROM users WHERE id = ?', [req.params.id])`. Do not use regex escapes.",
  "validation": {
    "method": "static source-to-sink trace + test harness",
    "status": "reportable",
    "summary": "Payload reaches sink; no middleware neutralizes input.",
    "assertions": ["GET /users/1' UNION SELECT ... leaks table"],
    "evidenceRefs": ["evidence-1"],
    "disposition": "reportable"
  },
  "attackPath": {
    "summary": "Unauthenticated GET to /users/:id reaches raw SQL.",
    "preconditions": ["Network access to edge service"],
    "steps": ["GET /users/1' UNION ...", "DB executes concatenated query", "Rows exfiltrated"],
    "reachability": {
      "summary": "Entry point exposed over HTTP without authz check.",
      "source": "req.params.id",
      "sink": "db.raw execution"
    },
    "dataFlow": {
      "source": "req.params.id in Express handler",
      "sink": "db.raw execution",
      "transformations": ["none – direct interpolation"]
    },
    "impact": { "level": "critical", "rationale": "Full table read / auth bypass" },
    "likelihood": { "level": "high", "rationale": "No sanitizer on path" }
  },
  "writeup": { "reportPath": "findings/sql-injection_raw-query/sql-injection_raw-query.md" },
  "provenance": { "source": "codex-security-scan" },
  "extensions": { "candidateId": "...", "ledgerRowId": "...", "reportId": "..." }
}
```

### Key fields explained

| Field | Type | Required | Notes |
| :--- | :--- | :--- | :--- |
| `findingId` | `string` `csf_[a-f0-9]{24}` | yes | Stable finding family id across scans (fingerprint-based). |
| `occurrenceId` | `string` `occ_[a-f0-9]{24}` | yes | Per-occurrence id; use with `findings false-positive <occurrenceId>`. |
| `ruleId` | `string` `^[a-z0-9][a-z0-9._/-]*$` | yes | Rule slug, e.g. `sql-injection.raw-query`, `xss.stored`. |
| `identity.anchor` | string | yes | Fingerprint anchor for cross-scan matching (`scans match/compare`). |
| `fingerprints.primary` | `codex-security/v1:sha256:<64 hex>` | yes | Primary fingerprint (`secrets`/`authz` etc. dedup relies on this). |
| `title` / `summary` | string | yes | Human-readable; `summary` is searchable by `scans match`. |
| `locations[]` | `{path, startLine, endLine?, role?}` | yes (≥1) | `role` can be `source`/`sink`/`intermediate`. `path` is repo-relative, `startLine` ≥1. |
| `taxonomy.category` / `cwe` | string / string[] | yes | CWE ids as strings `"CWE-89"` etc. |
| `remediation` | string | yes | **String**, not an object. Past docs showed `{guidance, suggestedFixDiff}` – current schema is a single markdown string. |
| `codeEvidence` / `code_evidence` | array | no | Primary field is camelCase `codeEvidence`; snake_case `code_evidence` is legacy alias. |
| `rootCause` / `root_cause` | object \| string | no | Prefer camelCase object `{summary, evidenceRefs, code, language}`. |
| `attackPath` | object | no | Contains `dataFlow`/`data_flow`/`dataflow` aliases, `reachability`, `impact`, `likelihood`, `steps`, `preconditions`. |
| `validation` | object | no | Contains `disposition`/`status`/`result` aliases; assertions evidence. |
| `writeup.reportPath` | `findings/<id>/<id>.md` | no | Markdown writeup on disk. |
| `provenance.source` | string | yes | Usually `codex-security-scan`. |

Legacy aliases (`code_evidence`, `root_cause`, `data_flow`, `evidence_refs`) are accepted on read for backward compat but SDK writes camelCase. Consumers should handle both.

---

## Finding IDs & triage lifecycle

- **Deduplication:** `fingerprints.primary` + `identity.anchor` are the dedup keys across component scans (`runComponentScans` deduplication summary) and `scans match/compare`.
- **Occurrence vs. finding:** One `findingId` may have multiple `occurrenceId`s across scans. Closing a false positive is per-`occurrenceId` via `npx @openai/codex-security findings false-positive <occurrenceId> --reason "..."`. The workbench persists to the scanned repo's state dir.
- **Lifecycle states from report/ledger:** Findings in `findings.json` are accompanied by `coverage.json` (surfaces) and `scan-manifest.json`. The `validation.disposition` field records triage outcome (see Validation Rubric).

---

## Example – reading findings programmatically

```ts
import { readFile } from "node:fs/promises";
import type { FindingsDocument } from "@openai/codex-security";

const doc: FindingsDocument = JSON.parse(await readFile("/tmp/scan/findings.json","utf8"));
for (const f of doc.findings) {
  console.log(`${f.severity.level.padEnd(13)} ${f.title}`);
  console.log(`  ${f.occurrenceId}  ${f.locations[0]?.path}:${f.locations[0]?.startLine}`);
  console.log(`  rule=${f.ruleId} cwe=${f.taxonomy.cwe.join(",")} confidence=${f.confidence.level}`);
  console.log(`  remediation: ${f.remediation.slice(0,120)}...`);
}
```

Filter for gating:

```bash
# Fail CI on high+ (same semantics as --fail-on-severity):
jq -e '.findings | map(select(.severity.level | IN("critical","high"))) | length==0' /tmp/scan/findings.json
```

Export for GitHub Code Scanning:

```bash
npx @openai/codex-security export /tmp/scan --export-format sarif --output results.sarif --source-root .
# then actions/upload-sarif in GitHub
```

---

## Validation Dispositions (from Validation Rubric)

Each `finding.validation.disposition` (also `validation.status`/`result` alias) is one of:

1. `reportable` – Confirmed with complete source→sink or reproducible proof.
2. `suppressed` – Mitigated by verified control or accepted false-positive rule.
3. `not_applicable` – Code not reachable / disabled by config / test fixture only.
4. `deferred` – Verification requires external infra not available in this run.

For full evidence hierarchy (dynamic crash → ASan → harness → interface → static trace) and dismissal criteria, see `references/validation-rubric.md`.

---

## Compatibility notes

- **Old skill shape:** `location:{path,startLine,endLine,...} description exploitability impact rootCause remediation.guidance evidence.source/sink/trace triage.status` – **not** current. Do not author findings in that shape for `security.validate()`; use `{title, location, description}` or full schema above. SDK `validate` accepts `string|object` for flexibility but the emitted report will normalize to the canonical schema above.
- **`remediation.suggestedFixDiff` does not exist** in current schema; remediation is a markdown string. Diffs appear inside report markdown, not JSON.
- **Severity is an object**, not a bare string. Helpers like `--fail-on-severity high` map internally to `severity.level >= high`.
