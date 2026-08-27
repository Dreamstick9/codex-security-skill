# Codex Security TypeScript SDK Reference

Version: `@openai/codex-security@0.1.20`. Types verified from `dist/*.d.ts` and `dist/index.d.ts`. SDK requires Node.js `^22.13.0 || ^24.0.0 || ^26.0.0` and Python 3.10+.

## Installation

```bash
npm install @openai/codex-security
# or
pnpm add @openai/codex-security
```

`package.json` declares `"type":"module"` – use ESM imports.

---

## Primary Exports

```ts
import {
  CodexSecurity,
  createSecurity,
  runComponentScans,
  planComponents,
  normalizeComponentPlan,
  estimateScanCost,
  publishScan,
  checkScanPublication,
  ScanResult,
} from "@openai/codex-security";

// Errors
import {
  CodexSecurityError,
  ConfigurationError,
  AuthenticationRequiredError,
  OutputDirectoryError,
  OutputDirectoryNotEmptyError,
  OutputInsideProtectedRootError,
  ScanCostLimitExceededError,
} from "@openai/codex-security";
```

Re-exports: all of `dist/models.d.ts` (`Finding`, `SeverityLevel`, `FindingsDocument`, `CoverageDocument`, `ScanManifest`, etc.), cost/linear/runtime helpers. See `dist/index.d.ts` for the full list.

> **Removed / non-existent APIs:** There is **no** `importGitHubCodeScanningAlerts`. The old example files that referenced it are incorrect. Use `publishScan`/`checkScanPublication` for Linear or handle GitHub SARIF via `export` + GitHub Code Scanning upload.

---

## 1. Class: `CodexSecurity`

### Constructor

```ts
const security = new CodexSecurity(options?: CodexSecurityConfig);
```

`CodexSecurityConfig` (from `dist/config.d.ts`):

```ts
interface CodexSecurityConfig {
  // Managed by SDK internally; rarely set by consumers:
  codexHome?: string;
  codexExecutable?: string;
  pluginPath?: string;        // dir or ZIP; defaults to bundled plugin
  pythonPath?: string;        // Python 3.10+
  codexOverrides?: Record<string, any>; // TOML overrides merged into Codex config
  // e.g. { model_reasoning_effort: "high" }
}
```

Example:

```ts
const security = new CodexSecurity({
  codexOverrides: { model_reasoning_effort: "high" },
  pythonPath: process.env.PYTHON,
});
```

Always call `close()` (or use `[Symbol.asyncDispose]`) to release locks and terminate workers:

```ts
try {
  // ...
} finally {
  await security.close();
}
// or with explicit resource management:
await using security = new CodexSecurity();
```

### `security.run(repository, options?): Promise<ScanResult>`

Full scan. `repository` is an absolute or repo-relative path (normalized internally).

```ts
const result: ScanResult = await security.run("/path/to/repo", {
  // Target & mode
  target: { kind: "repository" }, // or { kind:"path", path:"src/auth"} / {kind:"diff", base:"origin/main"} – see ScanTarget
  mode: "standard", // "standard" | "deep"
  // Output (must be outside repo; SDK creates + chmod 700)
  outputDir: "/tmp/outside/results",
  archiveExisting: false,
  // Budgets
  maxCostUsd: 10,
  // Auth
  auth: "auto", // "auto" | "chatgpt" | "api-key"
  safetyIdentifier: "hashed-user-123", // 1–64 chars
  // Knowledge base
  knowledgeBasePaths: ["docs/security/threat_model.md"],
  scanPrompt: "Focus on authz...",
  validationPrompt: undefined, // only non-deep
  postScanPrompt: undefined,
  // Observers – all optional
  onCost: (cost) => console.log(`$${cost.totalUsd.toFixed(2)}`),
  onProgress: (progress) => console.log(progress.phase, progress.filesCompleted),
  onWorkerStatus: (status) => console.log(`Worker ${status.workerNumber}: ${status.phase}`),
  onSessionEvent: (event) => console.log(event.threadId, event.event),
  onActivity: (activity) => console.log(activity.status),
  onWarning: (msg, details) => console.warn(msg, details),
  onAuthentication: (auth) => console.log(auth.method),
  onTrustedAccessStatus: (s) => console.log(s), // "granted"|"not_granted"|"unknown"
  onOutputDirReady: (dir) => console.log("Output ready:", dir),
  onOutputArchived: (dir) => console.log("Archived to:", dir),
  onScanStarted: () => console.log("Scan started"),
  onReconnect: (attempt, max, details) => console.log(`Reconnect ${attempt}/${max}`, details.reason),
  signal: abortController.signal,
});
console.log(result.scanId, result.reportPath, result.findings.findings.length);
console.log(result.metadata); // { startedAt, completedAt, mode, costUsd, filesScanned }
```

`ScanOptions` fully documented in `dist/api.d.ts` – extends `DeepScanOptions { workers, subagents, stopAfterNoNew, maxDiscoveryRuns, maxTimeHours }` plus the fields above.

Special handling:
- `failureSeverity` maps to CLI `--fail-on-severity`; SDK does not exit, inspect `result.findings`.
- `maxCostUsd` throws `ScanCostLimitExceededError` with `cost` + `scanDir`.

### `security.validate(options): Promise<ValidationResult>`

Validate a **single candidate finding** without persisting scan history. Does not write to repo.

```ts
const validation = await security.validate({
  repositoryPath: "/path/to/repo",
  finding: {
    title: "SQL Injection in User Search",
    location: "src/db/users.ts:88",
    description: "Unsanitized user input interpolated into SQL query.",
    // or full object shape matching findings schema
  },
  outputDir: "/tmp/outside/validation-out", // optional; SDK creates tmp if omitted
  auth: "auto",
  signal: abortController.signal,
});

console.log(validation.disposition); // "reportable"|"suppressed"|"not_applicable"|"deferred"
console.log(validation.report);      // markdown validation report
console.log(validation.outputDir, validation.threadId);
```

`finding` is `string | object`; strings are treated as finding text (never file paths), objects are JSON-serialized candidate payloads. Contract is in `dist/api.d.ts` (`VALIDATION_DISPOSITIONS`).

### `security.preflight(repository, options?): Promise<ScanPreflight>`

Validates config, target normalization, output dir, auth, model/provider without spending. Ideal for CI gating before `run`.

```ts
const preflight = await security.preflight("/path/to/repo", {
  mode: "standard",
  outputDir: "/tmp/outside/preflight",
});
if (!preflight.ready) {
  // In actual type `preflight` contains { issues, ... } – check returned fields
  console.error("Preflight errors:", preflight);
} else {
  console.log("Model:", preflight.model, preflight.reasoningEffort);
  console.log("Output:", preflight.outputDir);
  console.log("Auth:", preflight.authentication);
}
```

> Note: `ScanPreflight` shape is `{ repository, target, mode, knowledgeBasePaths?, outputDir, authentication, model, modelProvider?, reasoningEffort, maxCostUsd? }` – compare `dist/api.d.ts`. Older docs showed `{ready, issues}` which is not the current type; check `preflight.authentication` and catch `ConfigurationError` instead.

### Auth helpers on `CodexSecurity`

```ts
await security.loginApiKey(process.env.OPENAI_API_KEY!);
const handle = await security.loginChatGPT();           // browser flow
const handle2 = await security.loginChatGPTDeviceCode();// device flow
const status: AccountStatus = await security.account(); // credential state
await security.logout();
```

These wrap `CodexLoginHandle` (`dist/auth.d.ts`). Prefer env vars in CI (`OPENAI_API_KEY`, `CODEX_API_KEY`, `OPENROUTER_API_KEY` + provider, `AWS_BEARER_TOKEN_BEDROCK` + region).

### `security.close(): Promise<void>` / `[Symbol.asyncDispose]`

Stops workers, releases credential-home locks. Always in `finally` or `await using`.

---

## 2. Multi-Component Scanning: `runComponentScans`

For monorepos. Runs standard-mode scans per component + deduplication.

```ts
import { runComponentScans } from "@openai/codex-security";

const result = await runComponentScans({
  repository: "/path/to/monorepo",
  outputDir: "/tmp/component-results", // REQUIRED, outside repo
  components: [
    { name: "Frontend", paths: ["apps/web", "packages/ui"] },
    { name: "API Backend", paths: ["apps/api", "packages/database"] },
  ],
  auto: false,
  workers: 4,
  scanOptions: {
    maxCostUsd: 5,
    auth: "api-key",
    knowledgeBasePaths: ["docs/threat_model.md"],
  },
  onPlan: (receipts) => console.log("Plan:", receipts.length),
  onScanEvent: (event) => console.log(event.componentId, event.type),
  onProgress: (receipt) => console.log(receipt.name, receipt.status),
  onDeduplicationStarted: () => console.log("Dedup started"),
  onComplete: (r) => console.log(`Done: ${r.completed}/${r.total} findings=${r.findingCount}`),
  signal: ac.signal,
});
// result: { total, completed, incomplete, failed, planPath, summaryPath?, findingsPath?, reportPath?, retryPlanPath?, findingCount?, sourceFindingCount?, deduplication? }
```

`auto: true` lets the LLM propose components (writes `components.json` to `outputDir`). `planOnly: true` writes plan without scanning. See `dist/component-scan.d.ts`.

### Related: `planComponents` / `normalizeComponentPlan`

```ts
import { planComponents, normalizeComponentPlan } from "@openai/codex-security";

const plan = await planComponents("/path/to/repo", { signal: ac.signal });
console.log(plan.components);
// Validate an external plan:
const norm = await normalizeComponentPlan("/path/to/repo", JSON.parse(await readFile("components.json","utf8")));
```

Types: `ComponentPlan { components: {name, paths[]}[] }`, `ComponentPlanningOptions` (`dist/component-plan.d.ts`).

---

## 3. Cost Estimation: `estimateScanCost`

Pure function over session events (no IO).

```ts
import { estimateScanCost } from "@openai/codex-security";

const cost: ScanCost = estimateScanCost(sessionEvents);
console.log(`$${cost.totalUsd.toFixed(2)}  in=${cost.inputTokens} out=${cost.outputTokens} cached=${cost.cachedInputTokens ?? 0}`);
```

`ScanCost` shape from `dist/cost-model.d.ts`. `sessionEvents: ScanSessionEvent[]` are captured via `onSessionEvent`.

---

## 4. Linear Publication: `publishScan` / `checkScanPublication`

Push a completed scan's findings to Linear as issues.

```ts
import { publishScan, checkScanPublication } from "@openai/codex-security";

const ready = await checkScanPublication("/tmp/scan-dir", {
  destination: "linear",
  teamId: process.env.CODEX_SECURITY_LINEAR_TEAM!,
  projectId: process.env.CODEX_SECURITY_LINEAR_PROJECT, // optional
  linearApiKey: process.env.CODEX_SECURITY_LINEAR_API_KEY,
  assigneeId: "user@example.com", // optional
});

const result = await publishScan("/tmp/scan-dir", {
  destination: "linear",
  teamId: process.env.CODEX_SECURITY_LINEAR_TEAM!,
  projectId: process.env.CODEX_SECURITY_LINEAR_PROJECT,
  linearApiKey: process.env.CODEX_SECURITY_LINEAR_API_KEY,
  assigneeId: undefined,
  dryRun: false,       // preview without creating
  skipExisting: true,  // skip already published
  onProgress: (e) => {
    if (e.type === "issue_completed") console.log(`${e.findingId} -> ${e.issueIdentifier}`);
    if (e.type === "completed") console.log(`Created ${e.created}/${e.total}`);
  },
  signal: ac.signal,
});
console.log(result.created.length, result.failed.length, result.skipped?.length);
```

Options and progress types in `dist/publish.d.ts`. Warnings/errors are in `result.warnings` / `result.failed`.

---

## 5. `ScanResult` Interface (from `dist/result.d.ts` + `dist/models.d.ts`)

```ts
interface ScanResult {
  scanId: string;
  reportPath: string;   // markdown report
  outputDir: string;
  findings: {
    findings: Finding[]; // Finding = FindingsDocument["findings"][number]
    totalCount: number;
  };
  repositoryFindings?: Finding[];
  metadata: {
    startedAt: string;
    completedAt: string;
    mode: "standard" | "deep";
    costUsd: number;
    filesScanned: number;
  };
  // also: manifest (ScanManifest), coverage (CoverageDocument), raw paths
}
```

`Finding` shape is the full findings schema (see `references/finding-schema.md`): `findingId: csf_...`, `occurrenceId: occ_...`, `ruleId`, `identity`, `fingerprints (codex-security/v1:sha256:...)`, `severity {level, score?}`, `confidence`, `taxonomy {category, cwe[]}`, `locations[]`, `codeEvidence[]`, `rootCause`, `remediation`, `validation`, `attackPath`, `provenance`, etc. – see `dist/models.d.ts` / `_bundled_plugin/schemas/findings.schema.json`.

---

## 6. Errors (`dist/errors.d.ts`)

```ts
import {
  CodexSecurityError,
  ConfigurationError,
  AuthenticationRequiredError,
  OutputDirectoryError,
  OutputDirectoryNotEmptyError,      // .directory
  OutputInsideProtectedRootError,    // .outputDirectory .protectedRoot .pathKind
  ScanCostLimitExceededError,        // .maxCostUsd .cost .scanDir
  ScanInterruptedError,              // .scanDir
  ContractValidationError,
  PluginBootstrapError,
} from "@openai/codex-security";

try {
  await security.run(repo, { outputDir: "/tmp/out" });
} catch (e) {
  if (e instanceof OutputDirectoryNotEmptyError) {
    console.error("Empty the dir or set archiveExisting:true", e.directory);
  } else if (e instanceof ScanCostLimitExceededError) {
    console.error(`Cost cap $${e.maxCostUsd} exceeded, spent $${e.cost.totalUsd}`, e.scanDir);
  }
  throw e;
}
```

---

## 7. Runtime helpers (`dist/runtime.d.ts`)

Advanced: for custom plugin / Python routing.

```ts
import {
  bundledPluginRoot,
  resolvePluginPath,
  resolvePluginPython,
  prepareOutputDir,
  validateOutputDir,
  createIsolatedHome,
  bootstrapPlugin,
} from "@openai/codex-security";

const pluginRoot = await bundledPluginRoot();
const python = await resolvePluginPython({ environment: process.env });
const out = await prepareOutputDir("/tmp/custom-out", "my-repo", undefined, undefined, true);
```

Prefer `CodexSecurity` defaults unless you need to host the plugin yourself.

---

## 8. Migration notes from old docs

- `importGitHubCodeScanningAlerts` does not exist. For GitHub, run `npx @openai/codex-security export <scanDir> --export-format sarif --output results.sarif` then upload via `actions/upload-sarif`.
- `security.preflight` returns a `ScanPreflight` struct, not `{ready, issues}`. Check for thrown `ConfigurationError` and inspect `preflight.authentication`.
- `ScanOptions.target` uses `ScanTarget` union (not bare path strings). Use `{ kind:"repository" }` or helper `normalizeTarget` from `dist/targets.d.ts`.
- Default model is `gpt-5.6-sol`, default effort `xhigh` – not `high`.
