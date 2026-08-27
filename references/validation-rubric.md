# Finding Validation Rubric & Proof Methodologies

A core strength of Codex Security is its rejection of speculative findings in favor of evidence-backed validation. This document details the standard validation criteria and methods.

## Validation Hierarchy (Strongest to Least)

When validating candidate vulnerabilities, always attempt validation starting with the strongest realistic method:

```text
[1. Dynamic Crash / Crash PoC]
       │
       ▼
[2. Sanitizer / ASan / Valgrind]
       │
       ▼
[3. Non-Interactive Debugger Trace]
       │
       ▼
[4. Unit / Integration Test Harness Reproduction]
       │
       ▼
[5. Interface Reproduction (HTTP / CLI / RPC / File parser)]
       │
       ▼
[6. Code Understanding & Static Source-to-Sink Proof]
```

---

## 1. Dynamic Crash & Memory Safety PoC
- **Applicability**: C, C++, Rust (`unsafe`), Go (CGo), native extensions, parser bugs, buffer overflows, use-after-free, memory leaks leading to DoS.
- **Method**: Compile with debug symbols (`-g -O0`) and run a minimal test input that triggers the fault.
- **Criteria**: Segfault, abort, panic, or unhandled crash.

---

## 2. Sanitizers (ASan, UBSan, MSan) & Valgrind
- **Applicability**: Subtle memory corruptions, out-of-bounds reads/writes, integer overflows, uninitialized memory accesses.
- **Method**: Build with `-fsanitize=address,undefined` and feed crafted input.
- **Criteria**: ASan report indicating exact heap-buffer-overflow, stack-buffer-overflow, or UAF with backtrace.

---

## 3. Unit / Integration Test Harness Adaptation
- **Applicability**: Web frameworks, business logic, authorization bugs, regex DoS (ReDoS), cryptographic weaknesses.
- **Method**: Add or adapt a focused test in the existing project test suite (e.g. `pytest`, `jest`, `cargo test`) that passes a malicious payload and asserts unauthorized behavior (e.g. 200 OK instead of 403 Forbidden, or SQL injection payload execution).
- **Criteria**: The test fails or demonstrates invariant violation under malicious input.

---

## 4. Realistic Interface Reproduction
- **Applicability**: HTTP endpoints, CLI argument parsers, file format decoders, GraphQL resolvers, RPC handlers.
- **Method**: Construct a minimal input payload (e.g., JSON payload, HTTP header, CLI flag string) that reaches the vulnerable sink through the normal router or entry point.
- **Criteria**: Payload reaches the sink unescaped or triggers unauthorized state mutation.

---

## 5. Code Understanding & Static Proof (When Dynamic Execution is Blocked)
- **Applicability**: Missing external databases, cloud microservices, third-party authentication providers, or specialized hardware.
- **Requirements**:
  1. **Source**: Explicit user-controlled entry point (`req.body`, `argv`, socket read, URL parameter).
  2. **Control Flow**: Direct, unbroken call chain from Source to Sink.
  3. **Sanitization Absence**: Verification that no middleware, escape function, type validation, or ORM parameterization strips or neutralizes the malicious sequence.
  4. **Sink & Impact**: Concrete vulnerable API call (`eval()`, `exec()`, `raw_sql()`, `res.send(html)`, `system()`).
  5. **Proof Gap Check**: Active check for upstream defenses (WAF assumption is NOT a proof gap; application-level middleware IS a factor).

---

## Criteria for False Positive Dismissal

A candidate finding should be dismissed as a false positive or marked `suppressed` ONLY when:

1. **Active Sanitizer Verified**: Code uses a verified, contextual sanitizer or parameterized query prior to sink entry.
2. **Type Safety / Schema Enforcement**: Upstream validation (e.g., Zod, Pydantic, TypeScript strict types with runtime validation) strictly prevents unexpected structures or characters.
3. **Dead / Unreachable Code**: Entry point is unmounted, disabled by feature flag, or only present in test fixtures.
4. **Internal / Non-Attacker Surface**: Source is entirely derived from secure internal configuration or trusted environment variables that an external actor cannot modify.
5. **Prior User Feedback**: The occurrence matches an explicit user dismissal recorded in `findings false-positive`.
