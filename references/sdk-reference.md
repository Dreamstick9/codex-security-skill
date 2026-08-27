# Codex Security TypeScript SDK Reference

The `@openai/codex-security` package exports a high-level TypeScript API for automating scans, validating findings, component planning, and integrating security audits into CI/CD pipelines.

## Installation

```bash
npm install @openai/codex-security
```

*Requirements*: Node.js 22.13.0+ (or 24.x, 26.x), Python 3.10+.

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
  importGitHubCodeScanningAlerts,
  publishScan,
  checkScanPublication,
  ScanResult,
} from "@openai/codex-security";
```

---

## 1. Class: `CodexSecurity`

The central client for running scans and performing individual finding validations.

### Constructor

```ts
const security = new CodexSecurity(options?: CodexSecurityConfig);
```

#### `CodexSecurityConfig`:
- `pluginPath?: string`: Path to custom Codex Security plugin directory or ZIP (defaults to bundled plugin).
- `pythonPath?: string`: Custom Python interpreter path.
- `codexOverrides?: Record<string, any>`: Deep-merge override dictionary for Codex engine configuration.

### Methods

#### `security.run(repositoryPath, options?): Promise<ScanResult>`

Executes a full security scan on the specified repository.

```ts
const result = await security.run("/path/to/repository", {
  outputDir: "/path/outside/repository/results",
  mode: "standard", // "standard" | "deep"
  target: {
    kind: "repository", // or { kind: "diff", ref: "origin/main" }
  },
  knowledgeBasePaths: ["docs/threat_model.md"],
  maxCostUsd: 15.00,
  maxTimeHours: 4,
  auth: "auto", // "auto" | "chatgpt" | "api-key"
  safetyIdentifier: "hashed-user-123",
  onWorkerStatus: (status) => {
    console.log(`Worker ${status.workerNumber} phase: ${status.phase}`);
  },
  onSessionEvent: (event) => {
    console.log(`Session event: ${event.type}`);
  },
  signal: abortController.signal,
});
```

#### `security.validate(options): Promise<ValidationResult>`

Validates an individual candidate finding without altering the repository or recording a full scan.

```ts
const validation = await security.validate({
  repositoryPath: "/path/to/repository",
  finding: {
    title: "SQL Injection in User Search",
    location: "src/db/users.ts:88",
    description: "Unsanitized user input interpolated into SQL query.",
  },
  outputDir: "/path/outside/repo/validation-out",
  auth: "auto",
});

console.log("Disposition:", validation.disposition); // "reportable" | "suppressed" | "not_applicable" | "deferred"
console.log("Report:\n", validation.report);
```

#### `security.preflight(repositoryPath, options?): Promise<ScanPreflight>`

Validates local inputs, path resolution, and configuration without invoking models or network.

```ts
const preflight = await security.preflight("/path/to/repo", { mode: "standard" });
if (!preflight.ready) {
  console.error("Preflight errors:", preflight.issues);
}
```

#### `security.close(): Promise<void>`

Terminates background worker processes and cleans up temporary execution locks. Always call in a `finally` block.

---

## 2. Multi-Component Scanning: `runComponentScans`

```ts
import { runComponentScans } from "@openai/codex-security";

const result = await runComponentScans({
  repository: "/path/to/monorepo",
  outputDir: "/tmp/component-scan-results",
  components: [
    { name: "Frontend", paths: ["apps/web", "packages/ui"] },
    { name: "API Backend", paths: ["apps/api", "packages/database"] },
  ],
  workers: 4,
  scanOptions: {
    maxCostUsd: 5.0, // per component
    auth: "api-key",
  },
  onComponentProgress: (event) => {
    console.log(`Component ${event.componentName}: ${event.phase}`);
  },
});
```

---

## 3. GitHub Alert Import: `importGitHubCodeScanningAlerts`

```ts
import { importGitHubCodeScanningAlerts, CodexSecurity } from "@openai/codex-security";

const alerts = await importGitHubCodeScanningAlerts({
  repository: "org/repo",
  alertNumbers: [42, 43], // omit to import all open alerts
  state: "open", // "open" | "closed" | "dismissed" | "fixed" | "all"
  githubToken: process.env.GITHUB_TOKEN,
});

const security = new CodexSecurity();
try {
  for (const alert of alerts) {
    const check = await security.validate({
      repositoryPath: "/path/to/local/checkout",
      finding: alert,
    });
    console.log(`Alert #${alert.number}: ${check.disposition}`);
  }
} finally {
  await security.close();
}
```

---

## 4. Cost Estimation: `estimateScanCost`

```ts
import { estimateScanCost } from "@openai/codex-security";

const cost: ScanCost = estimateScanCost(sessionEvents);
console.log(`Total USD: \$${cost.totalUsd.toFixed(2)}`);
console.log(`Input Tokens: ${cost.inputTokens}, Output Tokens: ${cost.outputTokens}`);
```

---

## 5. ScanResult Object Structure

`ScanResult` encapsulates all findings, metadata, and generated artifact references:

```ts
interface ScanResult {
  scanId: string;
  reportPath: string;
  outputDir: string;
  findings: {
    findings: Finding[];
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
}
```
