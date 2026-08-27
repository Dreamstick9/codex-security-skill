# Automated Remediation, Verification & Patch Risk Assessment

Codex Security provides end-to-end remediation capabilities to automatically propose, test, and assess the risk of security patches.

## Remediation Workflow

```text
[Validated Finding]
        │
        ▼
[Synthesize Minimal Patch]
        │
        ▼
[Run Verification Suite] ──(Fails)──► [Refine / Rollback]
        │ (Passes)
        ▼
[Assess Patch Risk (Side Effects / API Breakage)]
        │
        ▼
[Generate Report / Draft Pull Request]
```

---

## 1. Minimal Patch Synthesis Principles

When generating code fixes for security vulnerabilities:

1. **Surgical Scope**: Fix the root cause without rewriting unrelated code or introducing unnecessary refactors.
2. **Preserve Public API Contracts**: Avoid breaking method signatures, return types, or parameter ordering unless the API design itself is inherently unfixable.
3. **Idiomatic Defensive Coding**:
   - For SQL: Parameterize queries or use typed query builders (never manual regex string escaping).
   - For Command Execution: Use argument arrays (`execFile`, `spawn(['ls', target])`) with `shell: false` (never `exec("cmd " + arg)`).
   - For Path Traversal: Canonicalize with `realpath` and assert the result starts with the base directory + separator (`resolved.startsWith(safeRoot + sep)`).
   - For XSS: Use context-aware template encodings or safe DOM setters (`textContent`, React JSX, sanitize-html).
   - For Auth / IDOR: Enforce tenancy / ownership checks at database query level (`WHERE id = ? AND organization_id = ?`).

---

## 2. Fix Verification (`verify-fix`)

Once a patch is synthesized, it is verified against the codebase:

1. **Regression Testing**: Run existing test suites (`npm test`, `pytest`, `cargo test`, `go test ./...`) to ensure standard functionality remains intact.
2. **Exploit Invariant Testing**: Re-run the validation proof or test harness created during the validation phase.
   - The test MUST now pass (i.e. the malicious payload is rejected or safely neutralized).

---

## 3. Patch Risk Assessment Rubric

The patch risk analyzer evaluates the candidate patch against three risk dimensions:

| Risk Dimension | Low Risk | Medium Risk | High / Critical Risk |
| :--- | :--- | :--- | :--- |
| **Behavioral Impact** | Strict input validation added without changing valid user flows. | Changes error handling status codes (e.g. 400 instead of 500) or error messages. | Changes fundamental business logic, data format, or drops previously supported features. |
| **API Compatibility** | Internal private helper updated; no public signatures altered. | Internal interface or non-exported type modified. | Exported public function signature or required parameters changed (breaking change). |
| **Performance Overhead** | Constant-time validation check (O(1)). | Added hash computation or single indexed database check. | Added unbounded regex, full table scan, or recursive file system traversal on hot path. |

---

## 4. CLI Patch Generation & Draft PR Creation

To trigger automatic patching and draft PR creation:

```bash
npx @openai/codex-security scan /path/to/repo \
  --patch \
  --patch-severity high \
  --create-pr \
  --output-dir /tmp/remediation-run
```

If successful, Codex Security will:
1. Create a dedicated Git branch (e.g., `codex-security/fix-finding-c4a1b2c3`).
2. Commit the surgical patch.
3. Push to upstream and open a GitHub Draft PR with the vulnerability writeup and verification logs.
