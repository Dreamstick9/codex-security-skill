#!/usr/bin/env bash
# ==============================================================================
# Codex Security CLI Cookbook & Practical Recipes
# ==============================================================================

set -euo pipefail

REPO_DIR="${1:-.}"
SCAN_TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
OUTPUT_BASE="/tmp/codex-security-scans/${SCAN_TIMESTAMP}"

echo "Target Repository: ${REPO_DIR}"
echo "Base Output Directory: ${OUTPUT_BASE}"

# ------------------------------------------------------------------------------
# 1. Quick Standard Scan (CI/CD Quality Gate)
# ------------------------------------------------------------------------------
recipe_quick_scan() {
  local out="${OUTPUT_BASE}/quick_scan"
  mkdir -p "${out}"
  echo "==> Running standard security scan..."

  npx @openai/codex-security scan "${REPO_DIR}" \
    --output-dir "${out}" \
    --fail-on-severity high
}

# ------------------------------------------------------------------------------
# 2. PR Review / Diff Scan Against Base Branch
# ------------------------------------------------------------------------------
recipe_pr_diff_scan() {
  local base_branch="${2:-origin/main}"
  local out="${OUTPUT_BASE}/pr_diff_scan"
  mkdir -p "${out}"
  echo "==> Running PR diff scan against ${base_branch}..."

  npx @openai/codex-security scan "${REPO_DIR}" \
    --diff "${base_branch}" \
    --output-dir "${out}" \
    --fail-on-severity high
}

# ------------------------------------------------------------------------------
# 3. Deep Multi-Worker Audit with Cost Budget
# ------------------------------------------------------------------------------
recipe_deep_audit() {
  local out="${OUTPUT_BASE}/deep_audit"
  mkdir -p "${out}"
  echo "==> Running deep multi-worker security audit..."

  npx @openai/codex-security scan "${REPO_DIR}" \
    --mode deep \
    --workers 4 \
    --subagents 2 \
    --max-cost 20.00 \
    --max-time-hours 6 \
    --stop-after-no-new 2 \
    --output-dir "${out}"
}

# ------------------------------------------------------------------------------
# 4. Scoped Audit on Sensitive Subsystems with Threat Model
# ------------------------------------------------------------------------------
recipe_scoped_auth_audit() {
  local out="${OUTPUT_BASE}/scoped_auth"
  mkdir -p "${out}"
  echo "==> Running scoped audit on authentication modules..."

  npx @openai/codex-security scan "${REPO_DIR}" \
    --path src/auth \
    --path src/middleware \
    --path src/crypto \
    --knowledge-base docs/security/threat_model.md \
    --output-dir "${out}"
}

# ------------------------------------------------------------------------------
# 5. Monorepo Multi-Component Scan
# ------------------------------------------------------------------------------
recipe_monorepo_scan() {
  local plan_dir="${OUTPUT_BASE}/monorepo_plan"
  local results_dir="${OUTPUT_BASE}/monorepo_results"
  mkdir -p "${plan_dir}" "${results_dir}"
  echo "==> Planning and scanning monorepo components..."

  # Step A: Auto-generate plan
  npx @openai/codex-security scan-components "${REPO_DIR}" \
    --auto \
    --plan-only \
    --output-dir "${plan_dir}"

  # Step B: Execute scan across components
  npx @openai/codex-security scan-components "${REPO_DIR}" \
    --components-file "${plan_dir}/components.json" \
    --workers 4 \
    --output-dir "${results_dir}"
}

# ------------------------------------------------------------------------------
# 6. Export to SARIF for GitHub Code Scanning
# ------------------------------------------------------------------------------
recipe_export_sarif() {
  local scan_dir="${1}"
  local sarif_out="${scan_dir}/results.sarif"
  echo "==> Exporting scan results to SARIF: ${sarif_out}"

  npx @openai/codex-security export \
    --scan-dir "${scan_dir}" \
    --format sarif \
    --output "${sarif_out}"
}

# ------------------------------------------------------------------------------
# 7. Auto-Patch & Open Draft Pull Request
# ------------------------------------------------------------------------------
recipe_auto_remediation() {
  local out="${OUTPUT_BASE}/remediation"
  mkdir -p "${out}"
  echo "==> Running scan with automated patch synthesis and PR creation..."

  npx @openai/codex-security scan "${REPO_DIR}" \
    --patch \
    --patch-severity high \
    --create-pr \
    --output-dir "${out}"
}

# Display available commands if run directly
echo "Codex Security recipes loaded. Call specific functions or run via script."
