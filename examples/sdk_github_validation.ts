import {
  CodexSecurity,
  importGitHubCodeScanningAlerts,
} from "@openai/codex-security";
import * as path from "node:path";
import * as os from "node:os";

async function main() {
  const repoSlug = process.env.GITHUB_REPOSITORY || "owner/repo";
  const localRepoPath = process.argv[2] || process.cwd();
  const githubToken = process.env.GITHUB_TOKEN || process.env.GH_TOKEN;

  if (!githubToken) {
    console.error("Error: GITHUB_TOKEN or GH_TOKEN environment variable required.");
    process.exit(1);
  }

  console.log(`Fetching open Code Scanning alerts for ${repoSlug}...`);
  const alerts = await importGitHubCodeScanningAlerts({
    repository: repoSlug,
    state: "open",
    githubToken,
  });

  console.log(`Found ${alerts.length} open alert(s).`);
  if (alerts.length === 0) return;

  const security = new CodexSecurity();
  const validationOutputDir = path.join(
    os.tmpdir(),
    `github-alert-validations-${Date.now()}`
  );

  try {
    for (const alert of alerts) {
      console.log(`\nValidating Alert #${alert.number}: ${alert.alert.rule.description || alert.alert.rule.id}`);
      
      const result = await security.validate({
        repositoryPath: localRepoPath,
        finding: alert,
        outputDir: path.join(validationOutputDir, `alert-${alert.number}`),
      });

      console.log(`-> Disposition: ${result.disposition.toUpperCase()}`);
      console.log(`-> Summary: ${result.report.slice(0, 160)}...`);
    }
  } finally {
    await security.close();
  }
}

main().catch(console.error);
