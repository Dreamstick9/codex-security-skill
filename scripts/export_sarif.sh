#!/usr/bin/env bash
# ==============================================================================
# export_sarif.sh - Export SARIF from a Codex Security scan directory (0.1.20)
# ==============================================================================
# Correct flags: export [scanDir] --export-format sarif --output <file> [--source-root]
# Old flags --scan-dir / --format were removed; this script is corrected.
# Usage: ./scripts/export_sarif.sh <scan_output_dir> [output_sarif_file] [--source-root <repo>]
#        SCAN_DIR is positional; --source-root improves fingerprints.
# Exit: 0 success, 2 usage/error

set -euo pipefail

usage() {
  cat <<EOF >&2
Usage: $(basename "$0") <scan_output_dir> [output_sarif_file] [--source-root <repo_path>] [--json|--csv]

  scan_output_dir   Completed scan directory (from run_security_scan.sh or --output-dir)
  output_sarif_file Output SARIF path (default: <scan_output_dir>/results.sarif)
  --source-root     Repository checkout for SARIF fingerprints (default: none)
  --json            Export JSON instead of SARIF (uses --export-format json)
  --csv             Export CSV instead of SARIF

Examples:
  $(basename "$0") /tmp/codex-security-scans/repo_20250101_120000
  $(basename "$0") /tmp/my-scan /tmp/results.sarif --source-root /path/to/repo
  $(basename "$0") /tmp/my-scan --json --output findings.json
  npx @openai/codex-security export /tmp/my-scan --export-format sarif --output results.sarif --source-root .
EOF
  exit 2
}

if [[ $# -lt 1 ]]; then usage; fi

SCAN_DIR="$1"; shift
OUTPUT_SARIF=""
SOURCE_ROOT=""
EXPORT_FMT="sarif"

# Parse optional positional output + flags
if [[ $# -ge 1 && ! "$1" =~ ^-- ]]; then
  OUTPUT_SARIF="$1"; shift
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --source-root) SOURCE_ROOT="$2"; shift 2 ;;
    --output) OUTPUT_SARIF="$2"; shift 2 ;;
    --json) EXPORT_FMT="json"; shift ;;
    --csv) EXPORT_FMT="csv"; shift ;;
    --sarif) EXPORT_FMT="sarif"; shift ;;
    -h|--help) usage ;;
    *) echo "Unknown option: $1" >&2; usage ;;
  esac
done

if [[ -z "${OUTPUT_SARIF}" ]]; then
  # CLI forbids writing inside scanDir (would overwrite scan artifact); default to sibling file
  SCAN_BASE="$(basename "${SCAN_DIR}")"
  SCAN_PARENT="$(dirname "${SCAN_DIR}")"
  case "${EXPORT_FMT}" in
    sarif) OUTPUT_SARIF="${SCAN_PARENT}/${SCAN_BASE}.sarif" ;;
    json)  OUTPUT_SARIF="${SCAN_PARENT}/${SCAN_BASE}.json" ;;
    csv)   OUTPUT_SARIF="${SCAN_PARENT}/${SCAN_BASE}.csv" ;;
  esac
  # fallback to CWD if parent is unwritable
  if [[ ! -w "$(dirname "${OUTPUT_SARIF}")" ]]; then
    case "${EXPORT_FMT}" in
      sarif) OUTPUT_SARIF="./results.sarif" ;;
      json)  OUTPUT_SARIF="./findings.json" ;;
      csv)   OUTPUT_SARIF="./findings.csv" ;;
    esac
  fi
fi

if [[ ! -d "${SCAN_DIR}" ]]; then
  echo "Error: Scan directory '${SCAN_DIR}' does not exist." >&2
  exit 2
fi
for req in findings.json scan-manifest.json; do
  if [[ ! -f "${SCAN_DIR}/${req}" ]]; then
    echo "Warning: '${SCAN_DIR}/${req}' missing; is '${SCAN_DIR}' a completed scan? (look for report.md)" >&2
  fi
done

echo "Exporting [${EXPORT_FMT}] from ${SCAN_DIR} -> ${OUTPUT_SARIF} ..."
# Reject output inside scanDir (CLI forbids writing inside scan artifact dir)
if [[ "${OUTPUT_SARIF}" == "${SCAN_DIR}"/* ]]; then
  echo "Error: --output '${OUTPUT_SARIF}' is inside scanDir '${SCAN_DIR}' (would overwrite artifact). Use sibling path: $(dirname "${SCAN_DIR}")/$(basename "${SCAN_DIR}").sarif" >&2
  exit 2
fi

CMD=(npx @openai/codex-security export "${SCAN_DIR}" --export-format "${EXPORT_FMT}" --output "${OUTPUT_SARIF}")
if [[ -n "${SOURCE_ROOT}" ]]; then
  if [[ ! -e "${SOURCE_ROOT}" ]]; then echo "Error: --source-root '${SOURCE_ROOT}' does not exist." >&2; exit 2; fi
  CMD+=(--source-root "${SOURCE_ROOT}")
fi

# Run with export diagnostics
set +e
"${CMD[@]}"
EC=$?
set -e
if [[ $EC -ne 0 ]]; then
  echo "Export failed (exit $EC). Try: npx @openai/codex-security export --help" >&2
  exit $EC
fi

echo "✓ Exported ${EXPORT_FMT} report: ${OUTPUT_SARIF}"
if [[ "${EXPORT_FMT}" == "sarif" ]]; then
  echo "  Upload to GitHub: gh api repos/{owner}/{repo}/code-scanning/sarifs or actions/upload-sarif"
fi
