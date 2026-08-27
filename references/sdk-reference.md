# Codex Security TypeScript SDK Reference

The `@openai/codex-security` package provides a programmatic TypeScript API for running scans, validating findings, planning components, and integrating security checks into build pipelines.

## Installation

```bash
npm install @openai/codex-security
```

System Requirements:
- Node.js 22.13.0 or later.
- Python 3.10 or later.

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

The `CodexSecurity` class executes security scans and finding validations.

### Constructor

```ts
const security = new CodexSecurity(options?: CodexSecurityConfig);
```

#### `CodexSecurityConfig` Properties:
- `pluginPath?: string`: Path to custom plugin folder or archive.
- `pythonPath?: string`: Path to Python executable.
- `codexOverrides?: Record<string, any>`: Configuration settings merged into the Codex engine configuration.

### Methods

#### `security.run(repositoryPath, options?): Promise<ScanResult>`

Execute a full scan on the target repository.

```ts
const result = await security.run("/path/to/repository", {
  outputDir: "/path/outside/repository/results",
  mode: "standard", // "standard" | "deep"
  target: {
    kind: "repository",
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

Validate an individual candidate finding without modifying repository files or saving scan history.

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

console.log("Disposition:", validation.disposition);
console.log("Report:\n", validation.report);
```

#### `security.preflight(repositoryPath, options?): Promise<ScanPreflight>`

Validate configuration, arguments, and local paths without invoking LLM models or network endpoints.

```ts
const preflight = await security.preflight("/path/to/repo", { mode: "standard" });
if (!preflight.ready) {
  console.error("Preflight errors:", preflight.issues);
}
```

#### `security.close(): Promise<void>`

Stop background workers and remove process locks. Always call this method in a `finally` block.

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
    maxCostUsd: 5.0,
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
  alertNumbers: [42, 43],
  state: "open",
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

## 5. `ScanResult` Interface

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
