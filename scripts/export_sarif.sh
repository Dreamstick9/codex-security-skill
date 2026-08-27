#!/usr/bin/env bash
# ==============================================================================
# export_sarif.sh - Helper script to export SARIF reports from a scan directory
# ==============================================================================

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $(basename "$0") <scan_output_dir> [output_sarif_file]" >&2
  exit 1
fi

SCAN_DIR="$1"
OUTPUT_SARIF="${2:-${SCAN_DIR}/results.sarif}"

if [[ ! -d "${SCAN_DIR}" ]]; then
  echo "Error: Scan directory '${SCAN_DIR}' does not exist." >&2
  exit 1
fi

echo "Exporting findings from ${SCAN_DIR} to SARIF at ${OUTPUT_SARIF}..."

npx @openai/codex-security export \
  --scan-dir "${SCAN_DIR}" \
  --format sarif \
  --output "${OUTPUT_SARIF}"

echo "Successfully exported SARIF report: ${OUTPUT_SARIF}"
