import { CodexSecurity, type ScanResult } from "@openai/codex-security";
import * as path from "node:path";
import * as os from "node:os";

async function main() {
  const repoPath = process.argv[2] || process.cwd();
  const outputDir = path.join(
    os.tmpdir(),
    `codex-security-sdk-${Date.now()}`
  );

  console.log(`Scanning repository: ${repoPath}`);
  console.log(`Output directory: ${outputDir}`);

  // Initialize client with high reasoning effort override
  const security = new CodexSecurity({
    codexOverrides: {
      model_reasoning_effort: "high",
    },
  });

  try {
    // 1. Run local preflight verification
    console.log("Checking preflight compatibility...");
    const preflight = await security.preflight(repoPath, { mode: "standard" });
    if (!preflight.ready) {
      console.error("Preflight check failed:", preflight.issues);
      process.exit(1);
    }
    console.log("Preflight ready.");

    // 2. Run full scan with live progress logging and cost guardrail
    const result: ScanResult = await security.run(repoPath, {
      outputDir,
      mode: "standard",
      maxCostUsd: 10.0,
      knowledgeBasePaths: [
        path.join(repoPath, "README.md"),
      ],
      onWorkerStatus: (status) => {
        console.log(`[Worker ${status.workerNumber}] Phase: ${status.phase}, Files: ${status.filesCompleted}/${status.filesTotal}`);
      },
      onSessionEvent: (event) => {
        if (event.type === "turn_completed") {
          console.log(`Turn completed for thread ${event.threadId}`);
        }
      },
    });

    // 3. Process and display findings summary
    console.log("\n================ Scan Complete ================");
    console.log(`Scan ID: ${result.scanId}`);
    console.log(`Total Findings: ${result.findings.findings.length}`);
    console.log(`Report Location: ${result.reportPath}`);

    for (const finding of result.findings.findings) {
      console.log(`\n- [${finding.severity.toUpperCase()}] ${finding.title}`);
      console.log(`  Location: ${finding.location.path}:${finding.location.startLine}`);
      console.log(`  Disposition: ${finding.disposition}`);
      console.log(`  Description: ${finding.description.slice(0, 120)}...`);
    }
  } catch (error) {
    console.error("Scan failed with error:", error);
    process.exit(1);
  } finally {
    // Always close client to release locks and terminate child workers
    await security.close();
  }
}

main().catch(console.error);
