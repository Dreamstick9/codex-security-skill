import { CodexSecurity } from "@openai/codex-security";
import * as path from "node:path";
import * as os from "node:os";
import * as fs from "node:fs/promises";

/**
 * Validate findings from an exported scan + optionally upload SARIF.
 *
 * The old pattern `importGitHubCodeScanningAlerts` does NOT exist in 0.1.20.
 * Correct flow:
 *   1. Run `npx @openai/codex-security scan . --output-dir /tmp/scan`
 *   2. Export: `npx @openai/codex-security export /tmp/scan --export-format sarif --output results.sarif`
 *   3. Optionally upload SARIF to GitHub via API or actions/upload-sarif
 *   4. Validate any candidate finding with `security.validate()`
 *
 * This script shows (a) validating a candidate finding and
 * (b) printing exported findings for SARIF upload.
 */

async function main() {
  const localRepoPath = process.argv[2] || process.cwd();
  const scanDir = process.argv[3]; // optional: path to completed scan dir (findings.json)

  // If a scan dir is given, summarize exported findings rather than faking GitHub import
  if (scanDir) {
    try {
      const raw = await fs.readFile(path.join(scanDir, "findings.json"), "utf8");
      const doc = JSON.parse(raw) as { findings: Array<{ findingId: string; occurrenceId: string; title: string; severity: { level: string } }> };
      console.log(`Found ${doc.findings.length} findings in ${scanDir}`);
      for (const f of doc.findings) {
        console.log(`- [${f.severity.level}] ${f.title} (${f.findingId} / ${f.occurrenceId})`);
      }
      console.log(`\nTo upload SARIF:\n  npx @openai/codex-security export "${scanDir}" --export-format sarif --output results.sarif --source-root "${localRepoPath}"`);
      console.log(`  gh api --method POST -H "Accept: application/vnd.github+json" /repos/{owner}/{repo}/code-scanning/sarifs -f sarif=@results.sarif -f ref=refs/heads/main`);
    } catch (e) {
      console.error(`Failed to read ${scanDir}/findings.json:`, e);
      process.exit(1);
    }
  }

  // Demonstrate standalone finding validation (no importGitHubCodeScanningAlerts)
  const security = new CodexSecurity();
  const validationOutputDir = path.join(os.tmpdir(), `codex-validate-${Date.now()}`);

  try {
    const candidate = {
      title: "Example: Unsanitized interpolation into SQL",
      location: "src/db/users.ts:88",
      description: "User input from req.params.id is interpolated into db.raw without binding.",
      // validation accepts string|object; string is treated as finding text
    };

    console.log(`\nValidating candidate finding against ${localRepoPath}...`);
    const result = await security.validate({
      repositoryPath: localRepoPath,
      finding: candidate,
      outputDir: validationOutputDir,
    });

    console.log(`-> Disposition: ${result.disposition.toUpperCase()}`); // reportable|suppressed|not_applicable|deferred
    console.log(`-> Thread: ${result.threadId ?? "n/a"}`);
    console.log(`-> Report (first 500 chars):\n${result.report.slice(0, 500)}...`);
    console.log(`-> Validation artifacts: ${result.outputDir}`);
  } finally {
    await security.close();
  }
}

main().catch(console.error);
