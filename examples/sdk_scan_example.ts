import { CodexSecurity, type ScanResult, ScanCostLimitExceededError, OutputDirectoryNotEmptyError } from "@openai/codex-security";
import * as path from "node:path";
import * as os from "node:os";

async function main() {
  const repoPath = process.argv[2] || process.cwd();
  const outputDir = path.join(os.tmpdir(), `codex-security-sdk-${Date.now()}`);

  console.log(`Scanning repository: ${repoPath}`);
  console.log(`Output directory: ${outputDir} (must be outside repo; chmod 700)`);

  // Bundled model: gpt-5.6-sol, effort xhigh by default. Override only if needed.
  const security = new CodexSecurity({
    codexOverrides: {
      model_reasoning_effort: "xhigh",
    },
  });

  try {
    // 1. Preflight without spending – validates target, outputDir, auth, model
    console.log("Checking preflight...");
    try {
      const preflight = await security.preflight(repoPath, {
        mode: "standard",
        outputDir,
        // auth: "auto" is default; knowledgeBasePaths: []
      });
      console.log(`Preflight ok: model=${preflight.model} effort=${preflight.reasoningEffort}`);
      console.log(`  outputDir=${preflight.outputDir}`);
      console.log(`  auth=${JSON.stringify(preflight.authentication)}`);
    } catch (e) {
      if (e instanceof OutputDirectoryNotEmptyError) {
        console.error(`Preflight: output dir not empty: ${e.directory} (use archiveExisting:true)`);
      }
      throw e;
    }

    // 2. Full scan with observers and cost guardrail
    const result: ScanResult = await security.run(repoPath, {
      outputDir,
      mode: "standard",
      maxCostUsd: 10.0,
      knowledgeBasePaths: [path.join(repoPath, "README.md")],
      // Fine-grained observers:
      onWorkerStatus: (status) => {
        console.log(`[Worker ${status.workerNumber}] Phase: ${status.phase}, Files: ${status.filesCompleted}/${status.filesTotal}`);
      },
      onSessionEvent: (event) => {
        // ScanSessionEvent shape: { threadId, parentThreadId, event: Record<string,unknown> }
        if ((event.event as any)?.type === "turn_completed") {
          console.log(`Turn completed for thread ${event.threadId}`);
        }
      },
      onProgress: (p) => console.log(`Progress: ${p.phase} ${p.filesCompleted}/${p.filesTotal}`),
      onCost: (cost) => console.log(`Cost so far: $${cost.totalUsd.toFixed(2)}`),
      onWarning: (msg) => console.warn(`Warning: ${msg}`),
      signal: AbortSignal.timeout(1000 * 60 * 30), // optional 30m cap
    });

    // 3. Display findings using CANONICAL schema (findings.json shape)
    console.log("\n================ Scan Complete ================");
    console.log(`Scan ID: ${result.scanId}`);
    console.log(`Report:  ${result.reportPath}`);
    console.log(`Findings: ${result.findings.findings.length} (totalCount=${result.findings.totalCount})`);
    console.log(`Meta: mode=${result.metadata.mode} cost=$${result.metadata.costUsd.toFixed(2)} files=${result.metadata.filesScanned}`);

    for (const f of result.findings.findings) {
      const loc = f.locations[0];
      const sev = f.severity.level; // severity is object, not string
      const disposition = (f.validation as any)?.disposition ?? (f.validation as any)?.status ?? "unknown";
      console.log(`\n- [${sev.toUpperCase()}] ${f.title} (${f.ruleId})`);
      console.log(`  ${f.findingId} / ${f.occurrenceId}`);
      console.log(`  Location: ${loc?.path}:${loc?.startLine}  confidence=${f.confidence.level}`);
      console.log(`  CWE: ${f.taxonomy.cwe.join(", ")}  disposition=${disposition}`);
      console.log(`  Summary: ${f.summary.slice(0, 160)}...`);
      console.log(`  Remediation: ${String(f.remediation).slice(0, 160)}...`);
    }

    // 4. Optional: export SARIF via CLI (SDK has no direct export; use CLI):
    //   npx @openai/codex-security export "${result.outputDir}" --export-format sarif --output results.sarif
  } catch (error) {
    if (error instanceof ScanCostLimitExceededError) {
      console.error(`Scan stopped: cost cap $${error.maxCostUsd} exceeded, spent $${error.cost.totalUsd.toFixed(2)} at ${error.scanDir}`);
    }
    console.error("Scan failed:", error);
    process.exit(1);
  } finally {
    await security.close(); // or `await using security = new CodexSecurity()`
  }
}

main().catch(console.error);
