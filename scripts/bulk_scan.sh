#!/usr/bin/env bash
# ==============================================================================
# bulk_scan.sh - Discover repositories and run resumable bulk security scans
# ==============================================================================
# Usage: ./scripts/bulk_scan.sh [options] [repositories.csv]
# Exit codes: 0 success, 2 error / usage
# ==============================================================================

set -euo pipefail

usage() {
  cat <<EOF >&2
Usage: $(basename "$0") [options] [repositories.csv]

Arguments:
  repositories.csv           CSV repository list (omit to discover interactively)

Options:
  -o, --output-dir <dir>     Resumable results directory (required with CSV)
  -w, --workers <count>      Concurrent repository scans (default: 4)
  -m, --mode <standard|deep> Default scan mode (default: standard)
  -c, --max-cost <usd>       Max cost per repository in USD
  --max-attempts <count>     Max scan attempts per repository (default: 1)
  -k, --knowledge-base <path> Shared documentation or security policy
  -e, --effort <lvl>         Reasoning effort (minimal|low|medium|high|xhigh|max)
  --model <model>            Model for repositories
  --provider <provider>      Inference provider (openai|openrouter|fireworks|amazon-bedrock)
  -h, --help                 Show this help message

Examples:
  $(basename "$0") repositories.csv --output-dir /tmp/bulk_results --workers 4
  $(basename "$0") --output-dir /tmp/bulk_results
EOF
  exit 2
}

CSV_FILE=""
OUTPUT_DIR=""
WORKERS=""
MODE=""
MAX_COST=""
MAX_ATTEMPTS=""
KB_PATHS=()
EFFORT=""
MODEL=""
PROVIDER=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -o|--output-dir)
      OUTPUT_DIR="$2"
      shift 2
      ;;
    -w|--workers)
      WORKERS="$2"
      shift 2
      ;;
    -m|--mode)
      MODE="$2"
      shift 2
      ;;
    -c|--max-cost)
      MAX_COST="$2"
      shift 2
      ;;
    --max-attempts)
      MAX_ATTEMPTS="$2"
      shift 2
      ;;
    -k|--knowledge-base)
      KB_PATHS+=("--knowledge-base" "$2")
      shift 2
      ;;
    -e|--effort)
      EFFORT="$2"
      shift 2
      ;;
    --model)
      MODEL="$2"
      shift 2
      ;;
    --provider)
      PROVIDER="$2"
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
      CSV_FILE="$1"
      shift
      ;;
  esac
done

CMD=(npx @openai/codex-security bulk-scan)

if [[ -n "${CSV_FILE}" ]]; then
  CMD+=("${CSV_FILE}")
fi

if [[ -n "${OUTPUT_DIR}" ]]; then
  CMD+=("--output-dir" "${OUTPUT_DIR}")
fi

if [[ -n "${WORKERS}" ]]; then
  CMD+=("--workers" "${WORKERS}")
fi

if [[ -n "${MODE}" ]]; then
  CMD+=("--mode" "${MODE}")
fi

if [[ -n "${MAX_COST}" ]]; then
  CMD+=("--max-cost" "${MAX_COST}")
fi

if [[ -n "${MAX_ATTEMPTS}" ]]; then
  CMD+=("--max-attempts" "${MAX_ATTEMPTS}")
fi

if [[ ${#KB_PATHS[@]} -gt 0 ]]; then
  CMD+=("${KB_PATHS[@]}")
fi

if [[ -n "${EFFORT}" ]]; then
  CMD+=("--effort" "${EFFORT}")
fi

if [[ -n "${MODEL}" ]]; then
  CMD+=("--model" "${MODEL}")
fi

if [[ -n "${PROVIDER}" ]]; then
  CMD+=("--provider" "${PROVIDER}")
fi

echo "============================================================"
echo "Codex Security: Bulk Scan"
echo "Command: ${CMD[*]}"
echo "============================================================"

set +e
"${CMD[@]}"
EXIT_CODE=$?
set -e

exit "${EXIT_CODE}"
