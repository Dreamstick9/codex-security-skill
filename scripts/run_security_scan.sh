#!/usr/bin/env bash
# ==============================================================================
# run_security_scan.sh - Safe wrapper for running Codex Security scans
# ==============================================================================

set -euo pipefail

usage() {
  cat <<EOF
Usage: $(basename "$0") [options] [repository_path]

Options:
  -m, --mode <standard|deep>    Scan mode (default: standard)
  -p, --path <subpath>          Scope scan to a specific path (repeatable)
  -d, --diff <git-ref>          Scan committed diff against ref (e.g., origin/main)
  -w, --working-tree            Scan uncommitted working tree changes
  -k, --knowledge-base <path>   Include threat model or security policy file
  -c, --max-cost <usd>          Set max estimated model cost in USD
  -f, --fail-on <severity>      Fail with exit code 1 on severity (critical|high|medium|low)
  -o, --output-dir <dir>        Custom output directory (default: isolated /tmp dir)
  -h, --help                    Show this help message

Examples:
  $(basename "$0") .
  $(basename "$0") --diff origin/main --fail-on high .
  $(basename "$0") --mode deep --max-cost 15.00 /path/to/project
EOF
  exit 1
}

MODE="standard"
FAIL_ON=""
DIFF_REF=""
WORKING_TREE=false
MAX_COST=""
OUTPUT_DIR=""
PATHS=()
KB_PATHS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    -m|--mode)
      MODE="$2"
      shift 2
      ;;
    -p|--path)
      PATHS+=("--path" "$2")
      shift 2
      ;;
    -d|--diff)
      DIFF_REF="$2"
      shift 2
      ;;
    -w|--working-tree)
      WORKING_TREE=true
      shift
      ;;
    -k|--knowledge-base)
      KB_PATHS+=("--knowledge-base" "$2")
      shift 2
      ;;
    -c|--max-cost)
      MAX_COST="$2"
      shift 2
      ;;
    -f|--fail-on)
      FAIL_ON="$2"
      shift 2
      ;;
    -o|--output-dir)
      OUTPUT_DIR="$2"
      shift 2
      ;;
    -h|--help)
      usage
      ;;
    -*)
      echo "Unknown option: $1" >&2
      usage
      ;;
    *)
      REPO_PATH="$1"
      shift
      ;;
  esac
done

REPO_PATH="${REPO_PATH:-.}"
REPO_PATH="$(cd "${REPO_PATH}" && pwd)"

if [[ -z "${OUTPUT_DIR}" ]]; then
  TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
  REPO_NAME="$(basename "${REPO_PATH}")"
  OUTPUT_DIR="/tmp/codex-security-scans/${REPO_NAME}_${TIMESTAMP}"
fi

mkdir -p "${OUTPUT_DIR}"
chmod 700 "${OUTPUT_DIR}"

CMD=(npx @openai/codex-security scan "${REPO_PATH}" --output-dir "${OUTPUT_DIR}" --mode "${MODE}")

if [[ ${#PATHS[@]} -gt 0 ]]; then
  CMD+=("${PATHS[@]}")
fi

if [[ -n "${DIFF_REF}" ]]; then
  CMD+=("--diff" "${DIFF_REF}")
fi

if [[ "${WORKING_TREE}" == "true" ]]; then
  CMD+=("--working-tree")
fi

if [[ ${#KB_PATHS[@]} -gt 0 ]]; then
  CMD+=("${KB_PATHS[@]}")
fi

if [[ -n "${MAX_COST}" ]]; then
  CMD+=("--max-cost" "${MAX_COST}")
fi

if [[ -n "${FAIL_ON}" ]]; then
  CMD+=("--fail-on-severity" "${FAIL_ON}")
fi

echo "============================================================"
echo "Starting Codex Security Scan"
echo "Repository: ${REPO_PATH}"
echo "Mode:       ${MODE}"
echo "Output Dir: ${OUTPUT_DIR}"
echo "============================================================"

set +e
"${CMD[@]}"
SCAN_EXIT_CODE=$?
set -e

echo ""
echo "============================================================"
echo "Scan Finished (Exit Code: ${SCAN_EXIT_CODE})"
echo "Artifacts and reports saved to: ${OUTPUT_DIR}"
if [[ -f "${OUTPUT_DIR}/report.md" ]]; then
  echo "Report: ${OUTPUT_DIR}/report.md"
fi
echo "============================================================"

exit "${SCAN_EXIT_CODE}"
