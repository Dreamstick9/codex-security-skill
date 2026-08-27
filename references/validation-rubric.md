# Finding Validation Rubric and Proof Methods

Codex Security uses evidence-based validation to verify candidate findings. This document defines the validation hierarchy and criteria for finding verification and dismissal.

## Validation Hierarchy

Apply validation methods in order of strongest evidence to static analysis:

```text
[1. Dynamic Crash / Fault Reproduction]
       │
       ▼
[2. Memory Sanitizers (ASan, UBSan, Valgrind)]
       │
       ▼
[3. Debugger Trace (gdb / lldb)]
       │
       ▼
[4. Test Harness Adaptation (Unit / Integration Test)]
       │
       ▼
[5. Interface Reproduction (HTTP / CLI / RPC)]
       │
       ▼
[6. Static Source-to-Sink Code Proof]
```

---

## 1. Dynamic Crash and Memory Safety Reproduction
- **Scope**: Native languages (C, C++, Rust), memory management defects, parser failures, buffer overflows, denial of service crashes.
- **Method**: Compile target with debug symbols (`-g -O0`) and run a minimal test input that triggers the fault.
- **Criteria**: Process termination via segmentation fault, abort, panic, or unhandled exception.

---

## 2. Sanitizers and Memory Checkers
- **Scope**: Out-of-bounds reads and writes, use-after-free, integer overflows, uninitialized memory access.
- **Method**: Compile with `-fsanitize=address,undefined` or run under Valgrind with malicious input.
- **Criteria**: AddressSanitizer report displaying memory corruption location and stack trace.

---

## 3. Test Harness Adaptation
- **Scope**: Web applications, authorization logic, business invariants, algorithmic complexity (ReDoS).
- **Method**: Add or adapt a test in the project test suite that supplies malicious input and asserts unauthorized state transition.
- **Criteria**: The automated test fails or demonstrates invariant violation under the provided test input.

---

## 4. Interface Reproduction
- **Scope**: HTTP endpoints, CLI argument parsers, file format decoders, RPC interfaces.
- **Method**: Send a crafted payload through the standard entry point to reach the suspected sink.
- **Criteria**: Payload reaches the sink without neutralization and executes the unauthorized operation.

---

## 5. Static Code Analysis and Source-to-Sink Proof
- **Scope**: Environments where external services, database instances, or cloud backends are unavailable.
- **Requirements**:
  1. **Source**: Explicit user-controlled entry point (`req.body`, `argv`, socket input).
  2. **Control Flow**: Direct, unbroken code path from Source to Sink.
  3. **Sanitization Absence**: Verification that no middleware, schema validation, or parameterization neutralizes the payload.
  4. **Sink**: Concrete vulnerable function execution (`eval()`, `exec()`, raw query).
  5. **Proof Gap Analysis**: Confirmation that no internal framework controls prevent execution.

---

## Criteria for False Positive Dismissal

Dismiss a finding as a false positive or assign `suppressed` disposition only when:

1. **Active Sanitizer Verified**: Code applies a contextual sanitizer or parameterized binding before data reaches the sink.
2. **Schema Enforcement**: Runtime validation (for example, Zod or Pydantic) rejects unexpected characters or payload structures.
3. **Dead Code**: Entry point is unmounted, disabled by build configuration, or located in test mock files.
4. **Trusted Boundary**: Input source originates exclusively from secure configuration files that external users cannot modify.
5. **Recorded Triage**: Finding occurrence matches an existing entry in the false positive registry.
