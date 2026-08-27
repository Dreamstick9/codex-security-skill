# Finding Schema & Vulnerability Taxonomy

Codex Security structures findings using a rigorous, standardized contract ensuring full traceability from vulnerable sink to root cause, evidence, and remediation advice.

## Severity Levels

| Severity | Definition | Examples |
| :--- | :--- | :--- |
| `critical` | Direct, remote, unauthenticated exploit leading to code execution, credential takeover, or severe data compromise. | Remote Code Execution (RCE), SQL Injection with auth bypass, Unauthenticated SSRF to cloud metadata. |
| `high` | Significant vulnerability requiring minimal privileges or user interaction, leading to sensitive data exposure or privilege escalation. | IDOR leaking private PII, Stored XSS in admin console, Hardcoded production secrets. |
| `medium` | Vulnerability requiring complex preconditions or specific environmental configurations. | CSRF on non-critical actions, Reflected XSS, Weak cryptography / hash algorithm usage. |
| `low` | Minor security weakness, defense-in-depth failure, or subtle information disclosure. | Verbose error stack traces, Missing security headers, Insecure cookie flags. |
| `informational` | Best practice improvement or code hardening suggestion without direct exploitability. | Deprecated crypto usage in non-security context, Redundant validation checks. |

---

## Finding Data Structure (JSON Schema)

Every finding in `findings.json` conforms to the following schema:

```json
{
  "id": "finding-c4a1b2c3",
  "occurrenceId": "occ-987f6e5d",
  "title": "SQL Injection in User Profile Lookup",
  "severity": "critical",
  "category": "CWE-89: Improper Neutralization of Special Elements used in an SQL Command",
  "location": {
    "path": "src/controllers/userController.ts",
    "startLine": 45,
    "endLine": 48,
    "startColumn": 12,
    "endColumn": 55,
    "snippet": "const user = await db.raw(`SELECT * FROM users WHERE id = '${req.params.id}'`);"
  },
  "disposition": "reportable",
  "description": "User-supplied parameter `req.params.id` is concatenated directly into a raw SQL query without parameterized binding or sanitization, enabling arbitrary SQL execution.",
  "exploitability": "High: Accessible via public GET /users/:id endpoint without authentication.",
  "impact": "An attacker can read entire database contents, bypass authentication, or modify tables.",
  "rootCause": "Direct string interpolation in `db.raw` query rather than utilizing parameterized placeholders.",
  "remediation": {
    "guidance": "Use parameterized query bindings: `db.raw('SELECT * FROM users WHERE id = ?', [req.params.id])` or the query builder `db('users').where({ id: req.params.id }).first()`.",
    "suggestedFixDiff": "--- a/src/controllers/userController.ts\n+++ b/src/controllers/userController.ts\n@@ -45,3 +45,3 @@\n-const user = await db.raw(`SELECT * FROM users WHERE id = '${req.params.id}'`);\n+const user = await db('users').where({ id: req.params.id }).first();"
  },
  "evidence": {
    "source": "req.params.id in Express handler",
    "sink": "db.raw execution",
    "trace": [
      "src/routes/users.ts:12 (Route registration)",
      "src/controllers/userController.ts:42 (Handler entry)",
      "src/controllers/userController.ts:45 (Raw query construction)"
    ],
    "proofOfConcept": "curl -k 'https://example.com/users/1%27%20UNION%20SELECT%20null,username,password%20FROM%20admins--'"
  },
  "triage": {
    "status": "open",
    "closeReason": null,
    "note": null
  }
}
```

---

## Validation Dispositions

When candidates are analyzed in the validation phase, one of four dispositions is assigned:

1. `reportable`:
   - High confidence vulnerability.
   - Traced source-to-sink dataflow with proven reachability or reproducible test/PoC.
2. `suppressed`:
   - Valid security concern that is mitigated upstream or matches an intentional, recorded user false-positive triage rule.
3. `not_applicable`:
   - The code is dead, disabled behind compile flags, or the environment lacks the necessary attack surface (e.g., test-only mock).
4. `deferred`:
   - Requires complex staging environment or third-party cloud setup that cannot be established within the scan constraints.
