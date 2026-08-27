# Remediation, Fix Verification, and Patch Risk Assessment

Codex Security provides automated remediation tools to generate, test, and assess code patches for identified vulnerabilities.

## Remediation Sequence

```text
[Confirmed Finding]
        │
        ▼
[Synthesize Minimal Patch]
        │
        ▼
[Run Verification Test Suite] ──(Fails)──► [Revise Patch / Revert]
        │ (Passes)
        ▼
[Evaluate Patch Risk (Compatibility / Side Effects)]
        │
        ▼
[Generate Report / Create Pull Request]
```

---

## 1. Patch Synthesis Rules

When generating code fixes:

1. **Limit Patch Scope**: Modify only the code necessary to resolve the vulnerability. Do not refactor unrelated functions.
2. **Preserve Public API Signatures**: Maintain parameter types, order, and function return types.
3. **Use Standard Defensive Patterns**:
   - **SQL**: Use parameterized placeholders or query builders. Do not use string concatenation or regular expression escapes.
   - **Command Execution**: Pass argument arrays to `execFile` or `spawn` with `shell: false`. Do not pass dynamic strings to shell interpreters.
   - **Path Traversal**: Resolve paths with `realpath` and assert the result starts with the intended directory root.
   - **Cross-Site Scripting (XSS)**: Use context-aware encoding or template-level sanitization.
   - **Authorization (IDOR)**: Enforce ownership checks directly in the data query filter (`WHERE id = ? AND tenant_id = ?`).

---

## 2. Fix Verification (`verify-fix`)

Verify the patch with two testing steps:

1. **Regression Testing**: Execute the project test suite (`npm test`, `pytest`, `cargo test`, `go test ./...`) to verify that standard functionality continues to operate.
2. **Exploit Invariant Testing**: Execute the test harness created during finding validation. The test must confirm that the malicious payload is rejected.

---

## 3. Patch Risk Evaluation Criteria

Evaluate patch risks across three dimensions:

| Risk Dimension | Low Risk | Medium Risk | High Risk |
| :--- | :--- | :--- | :--- |
| **Behavioral Impact** | Stricter input validation added without changing valid user operations. | Error response status code changed (for example, 400 instead of 500). | Core business logic modified or previously supported input formats dropped. |
| **API Compatibility** | Private internal function updated. | Internal interface or non-exported type modified. | Exported public function signature changed. |
| **Performance Impact** | Constant-time validation check added ($O(1)$). | Single indexed database lookup or cryptographic hash added. | Unbounded regular expression or disk scan added to hot request path. |

---

## 4. Automated Patch Generation

To execute a scan with automated patch generation and draft pull request creation:

```bash
npx @openai/codex-security scan /path/to/project \
  --patch \
  --patch-severity high \
  --create-pr \
  --output-dir /tmp/remediation-run
```
