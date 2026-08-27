# Threat Modeling and Attack Path Analysis

Codex Security uses threat modeling principles to identify security risks across component boundaries.

## STRIDE Threat Modeling Categories

Evaluate target systems against these six threat categories:

1. **Spoofing**: Can an attacker forge identity tokens, session cookies, API keys, or origin headers?
2. **Tampering**: Can an attacker modify request parameters, serialized objects, database records, or configuration files?
3. **Repudiation**: Can critical state changes (user deletion, permission changes, fund transfers) occur without audit logs?
4. **Information Disclosure**: Are secrets, tokens, debug traces, or tenant records returned in responses or error logs?
5. **Denial of Service**: Can an unauthenticated request exhaust memory, disk space, CPU cycles, or thread pools?
6. **Elevation of Privilege**: Can an unprivileged user execute administrator actions (for example, via IDOR or missing role checks)?

---

## Attack Path Components

An attack path documents the sequence of steps an attacker takes from entry point to target impact:

```text
[Step 1: Entry Point] ──► [Step 2: Perimeter Bypass] ──► [Step 3: Internal Pivot] ──► [Step 4: Sink Impact]
```

### Required Fields for Attack Paths:

1. **Preconditions**:
   - Network access requirements (Internet-facing or internal VPC).
   - Authentication requirements (Anonymous, standard user, or administrator).
   - System configuration prerequisites.
2. **Boundary Crossings**:
   - External Internet to edge service.
   - Edge service to internal database.
   - Tenant A data boundary to Tenant B data boundary.
3. **Exploit Mechanism**:
   - The specific software defect exploited at each step.
4. **Impact Metric**:
   - Severity of data loss, integrity violation, or service disruption.

---

## Supplying Threat Models to Scans

Provide existing threat models or architecture documents to the scanner using the `--knowledge-base` flag (repeatable, file or directory):

```bash
npx @openai/codex-security scan /path/to/repo \
  --knowledge-base docs/security/threat_model.md \
  --knowledge-base docs/architecture.md \
  --output-dir /tmp/threat-model-scan \
  --headless
# Output must be outside repository; --headless for CI; --dry-run to preflight without cost
# SDK: await security.run(repo, { knowledgeBasePaths: ["docs/security/threat_model.md"], outputDir: "/tmp/out" })
```
