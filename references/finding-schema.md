# Finding Schema and Vulnerability Taxonomy

Codex Security uses a standard data format for all security findings. This format provides traceability from source input to vulnerable sink, evidence, and remediation code.

## Severity Levels

| Severity | Definition | Examples |
| :--- | :--- | :--- |
| `critical` | Direct remote exploit without authentication leading to arbitrary code execution, privilege takeover, or critical data loss. | Remote Code Execution, Authentication Bypass, Server-Side Request Forgery to cloud metadata. |
| `high` | Vulnerability requiring minimal authentication or user interaction leading to private data exposure or privilege escalation. | Insecure Direct Object References (IDOR), Stored Cross-Site Scripting, Exposed production secrets. |
| `medium` | Vulnerability requiring non-standard preconditions or specific environment configurations. | Cross-Site Request Forgery (CSRF), Reflected XSS, Weak cryptographic primitives. |
| `low` | Minor security defect, defense-in-depth weakness, or information leak. | Detailed error stack traces in responses, Missing security headers, Insecure cookie attributes. |
| `informational` | Code hardening suggestion or best practice improvement without direct exploitability. | Deprecated crypto function used in non-security context, Redundant validation logic. |

---

## Finding JSON Structure

Every record in `findings.json` conforms to the following schema:

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
  "description": "User input from req.params.id is concatenated directly into a raw SQL query string without parameter binding.",
  "exploitability": "High: The endpoint is exposed publicly over HTTP without authentication.",
  "impact": "An attacker can read database tables, bypass authentication checks, or modify records.",
  "rootCause": "String interpolation in raw SQL query instead of parameterized placeholders.",
  "remediation": {
    "guidance": "Use parameterized query bindings or a query builder method.",
    "suggestedFixDiff": "--- a/src/controllers/userController.ts\n+++ b/src/controllers/userController.ts\n@@ -45,3 +45,3 @@\n-const user = await db.raw(`SELECT * FROM users WHERE id = '${req.params.id}'`);\n+const user = await db('users').where({ id: req.params.id }).first();"
  },
  "evidence": {
    "source": "req.params.id in Express handler",
    "sink": "db.raw execution",
    "trace": [
      "src/routes/users.ts:12",
      "src/controllers/userController.ts:42",
      "src/controllers/userController.ts:45"
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

During the validation phase, each candidate finding is assigned one of four dispositions:

1. `reportable`:
   - Confirmed vulnerability with complete source-to-sink reachability or reproducible test proof.
2. `suppressed`:
   - Defect mitigated by upstream security controls or marked as an accepted false positive.
3. `not_applicable`:
   - Code is not reachable, disabled by configuration, or located in test fixtures only.
4. `deferred`:
   - Verification requires external infrastructure not available in the current scan run.
