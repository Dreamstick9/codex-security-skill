# Threat Modeling & Attack Path Analysis

Codex Security uses threat modeling principles to discover non-obvious, chained vulnerabilities across trust boundaries.

## Threat Modeling Framework (STRIDE Adapted)

When evaluating architecture or analyzing candidate vulnerabilities:

1. **Spoofing**: Can an attacker forge identities, JWT tokens, API keys, session cookies, or origin headers?
2. **Tampering**: Can parameters, serialized objects, hidden fields, cryptographic MACs, or database records be modified without detection?
3. **Repudiation**: Can critical security actions (transfers, deletions, permission grants) occur without unalterable audit trails?
4. **Information Disclosure**: Are secrets, tokens, debug traces, PII, internal IPs, or tenant data exposed via responses, logs, or side channels?
5. **Denial of Service**: Can unauthenticated requests exhaust CPU (ReDoS, quadratic algorithms), memory (decompression bombs), disk, or connection pools?
6. **Elevation of Privilege**: Can a low-privileged tenant, guest user, or standard token perform administrative actions (IDOR, missing role checks, mass assignment)?

---

## Attack Path Analysis

Attack paths document the exact multi-step progression from initial access to objective impact:

```text
[Step 1: Entry Point] ──► [Step 2: Perimeter Bypass] ──► [Step 3: Lateral Movement] ──► [Step 4: Impact Sink]
(Unauth Webhook API)        (Missing HMAC Signature)       (Internal RPC injection)       (Database Exfiltration)
```

### Key Components of an Attack Path:

1. **Preconditions**:
   - Network location (Internet-facing vs VPC-internal).
   - Authentication status (Anonymous, standard user, admin).
   - System prerequisites (Specific database engine, OS features, specific config flags).
2. **Boundary Crossings**:
   - Untrusted internet to DMZ.
   - DMZ to internal microservices.
   - User space to Kernel space.
   - Tenant A space to Tenant B space (Cross-Tenant violation).
3. **Exploitation Mechanism**:
   - The exact vulnerability exploited at each transition node.
4. **Final Impact**:
   - Confidentiality, Integrity, or Availability loss metrics.

---

## Providing Knowledge Base Threat Models to Scans

You can provide existing threat model documents or system architecture diagrams (in Markdown/PDF) directly to Codex Security scans using the `--knowledge-base` flag:

```bash
npx @openai/codex-security scan /path/to/repo \
  --knowledge-base docs/architecture/threat_model.md \
  --knowledge-base docs/security/trust_boundaries.md \
  --output-dir /tmp/context-aware-scan
```

This grounds discovery workers in the project's explicit security invariants and intended trust boundaries.
