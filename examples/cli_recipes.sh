#!/usr/bin/env bash
# ==============================================================================
# Codex Security CLI Cookbook & Practical Recipes (0.1.20)
# ==============================================================================
# Verified against: scan/scan-components/export/findings/scans/patch/validate/bulk-scan/publish
# Each recipe is a function; source this file or call directly.
# Correct export flags: export [scanDir] --export-format sarif --output file

set -euo pipefail

REPO_DIR="${1:-.}"
SCAN_TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
OUTPUT_BASE="/tmp/codex-security-scans/${SCAN_TIMESTAMP}"
REPO_ABS="$(cd "${REPO_DIR}" 2>/dev/null && pwd || echo "${REPO_DIR}")"

echo "Target Repository: ${REPO_ABS}"
echo "Base Output Directory: ${OUTPUT_BASE}"
echo "Hint: run with --dry-run first to preflight without cost."
echo ""

# ------------------------------------------------------------------------------
# 1. Quick Standard Scan (CI/CD Quality Gate)
# ------------------------------------------------------------------------------
recipe_quick_scan() {
  local out="${OUTPUT_BASE}/quick_scan"
  mkdir -p "${out}" && chmod 700 "${out}"
  echo "==> Running standard security scan (headless, fail on high)..."
  npx @openai/codex-security scan "${REPO_DIR}" \
    --output-dir "${out}" \
    --fail-on-severity high \
    --headless
}

# ------------------------------------------------------------------------------
# 2. PR Review / Diff Scan Against Base Branch
# ------------------------------------------------------------------------------
recipe_pr_diff_scan() {
  local base_branch="${2:-origin/main}"
  local out="${OUTPUT_BASE}/pr_diff_scan"
  mkdir -p "${out}" && chmod 700 "${out}"
  echo "==> Running PR diff scan against ${base_branch}..."
  npx @openai/codex-security scan "${REPO_DIR}" \
    --diff "${base_branch}" \
    --output-dir "${out}" \
    --fail-on-severity high \
    --headless
}

# ------------------------------------------------------------------------------
# 3. Deep Multi-Worker Audit with Cost Budget
# ------------------------------------------------------------------------------
recipe_deep_audit() {
  local out="${OUTPUT_BASE}/deep_audit"
  mkdir -p "${out}" && chmod 700 "${out}"
  echo "==> Running deep multi-worker security audit..."
  npx @openai/codex-security scan "${REPO_DIR}" \
    --mode deep \
    --workers 4 \
    --subagents 2 \
    --max-cost 20.00 \
    --max-time-hours 6 \
    --stop-after-no-new 2 \
    --output-dir "${out}" \
    --headless
}

# ------------------------------------------------------------------------------
# 4. Scoped Audit on Sensitive Subsystems with Threat Model
# ------------------------------------------------------------------------------
recipe_scoped_auth_audit() {
  local out="${OUTPUT_BASE}/scoped_auth"
  mkdir -p "${out}" && chmod 700 "${out}"
  echo "==> Running scoped audit on authentication modules..."
  # Accept --path repeat; add knowledge-base if file exists
  local kb_args=()
  if [[ -f "${REPO_DIR}/docs/security/threat_model.md" ]]; then
    kb_args+=(--knowledge-base "docs/security/threat_model.md")
  elif [[ -f "${REPO_DIR}/docs/threat_model.md" ]]; then
    kb_args+=(--knowledge-base "docs/threat_model.md")
  else
    echo "  (no threat_model.md found; running without --knowledge-base)"
  fi
  npx @openai/codex-security scan "${REPO_DIR}" \
    --path src/auth \
    --path src/middleware \
    --path src/crypto \
    "${kb_args[@]}" \
    --output-dir "${out}" \
    --headless
}

# ------------------------------------------------------------------------------
# 5. Monorepo Multi-Component Scan
# ------------------------------------------------------------------------------
recipe_monorepo_scan() {
  local plan_dir="${OUTPUT_BASE}/monorepo_plan"
  local results_dir="${OUTPUT_BASE}/monorepo_results"
  mkdir -p "${plan_dir}" "${results_dir}" && chmod 700 "${plan_dir}" "${results_dir}"
  echo "==> Planning and scanning monorepo components..."

  # Step A: Auto-generate plan
  npx @openai/codex-security scan-components "${REPO_DIR}" \
    --auto \
    --plan-only \
    --output-dir "${plan_dir}"

  echo "  Plan written to ${plan_dir}/components.json"
  cat "${plan_dir}/components.json" | head -n 80

  # Step B: Execute scan across components
  npx @openai/codex-security scan-components "${REPO_DIR}" \
    --components-file "${plan_dir}/components.json" \
    --workers 4 \
    --output-dir "${results_dir}" \
    --headless
}

# ------------------------------------------------------------------------------
# 6. Export to SARIF for GitHub Code Scanning
# ------------------------------------------------------------------------------
recipe_export_sarif() {
  local scan_dir="${1}"
  if [[ -z "${scan_dir}" ]]; then echo "Usage: recipe_export_sarif <scan_dir>" >&2; return 2; fi
  local sarif_out="$(dirname "${scan_dir}")/$(basename "${scan_dir}").sarif"
  echo "==> Exporting scan results to SARIF: ${sarif_out}"
  # Correct flags: positional scanDir + --export-format + --source-root (cannot write inside scanDir)
  npx @openai/codex-security export "${scan_dir}" \
    --export-format sarif \
    --output "${sarif_out}" \
    --source-root "${REPO_DIR}"
  echo "  Upload: gh api repos/{owner}/{repo}/code-scanning/sarifs or actions/upload-sarif"
}

# Also export JSON/CSV variants
recipe_export_json_csv() {
  local scan_dir="${1}"
  if [[ -z "${scan_dir}" ]]; then echo "Usage: recipe_export_json_csv <scan_dir>" >&2; return 2; fi
  npx @openai/codex-security export "${scan_dir}" --export-format json --output "$(dirname "${scan_dir}")/$(basename "${scan_dir}").json"
  npx @openai/codex-security export "${scan_dir}" --export-format csv  --output "$(dirname "${scan_dir}")/$(basename "${scan_dir}").csv"
  echo "  Wrote $(dirname "${scan_dir}")/$(basename "${scan_dir}").{json,csv} (sibling to scanDir; CLI forbids inside)"
}

# ------------------------------------------------------------------------------
# 7. Auto-Patch & Open Draft Pull Request (inline)
# ------------------------------------------------------------------------------
recipe_auto_remediation() {
  local out="${OUTPUT_BASE}/remediation"
  mkdir -p "${out}" && chmod 700 "${out}"
  echo "==> Running scan with automated patch synthesis and PR creation..."
  npx @openai/codex-security scan "${REPO_DIR}" \
    --patch \
    --patch-severity high \
    --create-pr \
    --output-dir "${out}" \
    --headless
}

# ------------------------------------------------------------------------------
# 8. Standalone patch / verify-fix (from saved scan)
# ------------------------------------------------------------------------------
recipe_patch_from_scan() {
  local scan_id="${1}"
  if [[ -z "${scan_id}" ]]; then echo "Usage: recipe_patch_from_scan <scanId>" >&2; return 2; fi
  npx @openai/codex-security patch --scan "${scan_id}" --severity high --create-pr
}
recipe_verify_fix() {
  local scan_id="${1}"
  if [[ -z "${scan_id}" ]]; then echo "Usage: recipe_verify_fix <scanId>" >&2; return 2; fi
  npx @openai/codex-security verify-fix --scan "${scan_id}" --severity high
}

# ------------------------------------------------------------------------------
# 9. Bulk scan + publish to Linear
# ------------------------------------------------------------------------------
recipe_bulk_scan() {
  local csv="${1:-}"
  local out="${OUTPUT_BASE}/bulk"
  mkdir -p "${out}" && chmod 700 "${out}"
  if [[ -n "${csv}" ]]; then
    npx @openai/codex-security bulk-scan "${csv}" --output-dir "${out}" --workers 4 --max-attempts 3
  else
    echo "==> Bulk scan (interactive discovery)..."
    npx @openai/codex-security bulk-scan --output-dir "${out}" --workers 4
  fi
}
recipe_publish_linear() {
  local scan_dir="${1}"
  if [[ -z "${scan_dir}" ]]; then echo "Usage: recipe_publish_linear <scan_dir>" >&2; return 2; fi
  npx @openai/codex-security publish scan "${scan_dir}" --to linear --dry-run
  echo "Remove --dry-run to actually create Linear issues."
}

# ------------------------------------------------------------------------------
# 10. Dry-run preflight
# ------------------------------------------------------------------------------
recipe_dry_run() {
  echo "==> Dry-run preflight (no cost)..."
  npx @openai/codex-security scan "${REPO_DIR}" --dry-run
}

# Display available commands if run directly
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  cat <<EOH
Codex Security recipes loaded. Available functions:
  recipe_quick_scan
  recipe_pr_diff_scan [base_branch]
  recipe_deep_audit
  recipe_scoped_auth_audit
  recipe_monorepo_scan
  recipe_export_sarif <scan_dir>
  recipe_export_json_csv <scan_dir>
  recipe_auto_remediation
  recipe_patch_from_scan <scanId>
  recipe_verify_fix <scanId>
  recipe_bulk_scan [repositories.csv]
  recipe_publish_linear <scan_dir>
  recipe_dry_run

Run e.g.: bash examples/cli_recipes.sh . && recipe_quick_scan
Or source: source examples/cli_recipes.sh && recipe_dry_run
EOH
fi
