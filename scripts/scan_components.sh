#!/usr/bin/env bash
# ==============================================================================
# scan_components.sh - Monorepo component scan planner and runner
# ==============================================================================
# Usage: ./scripts/scan_components.sh [options] [repository_path]
# Exit codes: 0 success, 1 findings tripped, 2 error / usage
# ==============================================================================

set -euo pipefail

usage() {
  cat <<EOF >&2
Usage: $(basename "$0") [options] [repository_path]

Options:
  --auto                      Ask Codex to automatically divide the repository into components
  --plan-only                 Generate and save components.json plan without scanning
  --components-file <file>    Read component plan from JSON file
  --component <path>          Specify component path manually (repeatable)
  -w, --workers <count>       Concurrent component scans (default: 4)
  -c, --max-cost <usd>        Max cost per component in USD
  -o, --output-dir <dir>      Output directory for plan or scan results
  -k, --knowledge-base <path> Shared documentation or security policy
  -e, --effort <lvl>          Reasoning effort (minimal|low|medium|high|xhigh|max)
  --model <model>             Model for planning and scanning
  --provider <provider>       Inference provider (openai|openrouter|fireworks|amazon-bedrock)
  --headless                  Force plain-text status output
  -h, --help                  Show this help message

Examples:
  # 1. Generate component plan:
  $(basename "$0") --auto --plan-only --output-dir /tmp/monorepo_plan .

  # 2. Run scans from generated plan:
  $(basename "$0") --components-file /tmp/monorepo_plan/components.json --workers 4 --output-dir /tmp/monorepo_results .
EOF
  exit 2
}

REPO_PATH="."
AUTO=false
PLAN_ONLY=false
COMPONENTS_FILE=""
COMPONENTS=()
WORKERS=""
MAX_COST=""
OUTPUT_DIR=""
KB_PATHS=()
EFFORT=""
MODEL=""
PROVIDER=""
HEADLESS=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --auto)
      AUTO=true
      shift
      ;;
    --plan-only)
      PLAN_ONLY=true
      shift
      ;;
    --components-file)
      COMPONENTS_FILE="$2"
      shift 2
      ;;
    --component)
      COMPONENTS+=("--component" "$2")
      shift 2
      ;;
    -w|--workers)
      WORKERS="$2"
      shift 2
      ;;
    -c|--max-cost)
      MAX_COST="$2"
      shift 2
      ;;
    -o|--output-dir)
      OUTPUT_DIR="$2"
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
    --headless)
      HEADLESS=true
      shift
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

REPO_PATH="$(cd "${REPO_PATH}" && pwd)"

if [[ -z "${OUTPUT_DIR}" ]]; then
  TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
  OUTPUT_DIR="/tmp/codex-security-components/${TIMESTAMP}"
fi

mkdir -p "${OUTPUT_DIR}"
chmod 700 "${OUTPUT_DIR}"

CMD=(npx @openai/codex-security scan-components "${REPO_PATH}" --output-dir "${OUTPUT_DIR}")

if [[ "${AUTO}" == "true" ]]; then
  CMD+=("--auto")
fi

if [[ "${PLAN_ONLY}" == "true" ]]; then
  CMD+=("--plan-only")
fi

if [[ -n "${COMPONENTS_FILE}" ]]; then
  CMD+=("--components-file" "${COMPONENTS_FILE}")
fi

if [[ ${#COMPONENTS[@]} -gt 0 ]]; then
  CMD+=("${COMPONENTS[@]}")
fi

if [[ -n "${WORKERS}" ]]; then
  CMD+=("--workers" "${WORKERS}")
fi

if [[ -n "${MAX_COST}" ]]; then
  CMD+=("--max-cost" "${MAX_COST}")
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

if [[ "${HEADLESS}" == "true" || -n "${CI:-}" || ! -t 1 ]]; then
  CMD+=("--headless")
fi

echo "============================================================"
echo "Codex Security: Component Scan"
echo "Repository: ${REPO_PATH}"
echo "Output Dir: ${OUTPUT_DIR}"
echo "Command:    ${CMD[*]}"
echo "============================================================"

set +e
"${CMD[@]}"
EXIT_CODE=$?
set -e

exit "${EXIT_CODE}"
