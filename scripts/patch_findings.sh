#!/usr/bin/env bash
# ==============================================================================
# patch_findings.sh - Generate and verify security patches using Codex Security
# ==============================================================================
# Usage: ./scripts/patch_findings.sh [options] [issue_files_or_text...]
# Exit codes: 0 success, 2 error / usage
# ==============================================================================

set -euo pipefail

usage() {
  cat <<EOF >&2
Usage: $(basename "$0") [options] [issue_files_or_text...]

Options:
  --scan <scan-id>          Patch open findings from a saved scan ID or 'latest'
  --severity <lvl>          Patch findings at or above level (critical|high|medium|low)
  --create-pr               Create a draft GitHub pull request after verified patches
  --resume-pr <branch>      Resume publication of a saved patch branch
  --linear-issue <id>       Linear issue identifier or URL (repeatable)
  --linear-project <id>     Patch every open issue in this Linear project
  --linear-filter <json>    JSON Linear issue filter for --linear-project
  --linear-api-key <key>    Linear personal API key (default: CODEX_SECURITY_LINEAR_API_KEY)
  -e, --effort <lvl>        Reasoning effort (minimal|low|medium|high|xhigh|max, default: xhigh)
  --format <fmt>            CLI output format (toon|json|yaml|md|jsonl)
  --codex <key=val>         Codex config override
  -h, --help                Show this help message

Examples:
  # Patch all high/critical findings from latest scan:
  $(basename "$0") --scan latest --severity high

  # Patch and create a GitHub PR:
  $(basename "$0") --scan latest --severity high --create-pr

  # Patch a specific finding file:
  $(basename "$0") /tmp/finding.json --create-pr
EOF
  exit 2
}

SCAN_ID=""
SEVERITY=""
CREATE_PR=false
RESUME_PR=""
LINEAR_ISSUES=()
LINEAR_PROJECT=""
LINEAR_FILTER=""
LINEAR_API_KEY=""
EFFORT=""
FORMAT=""
CODEX_OVERRIDES=()
ISSUE_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --scan)
      SCAN_ID="$2"
      shift 2
      ;;
    --severity)
      SEVERITY="$2"
      shift 2
      ;;
    --create-pr)
      CREATE_PR=true
      shift
      ;;
    --resume-pr)
      RESUME_PR="$2"
      shift 2
      ;;
    --linear-issue)
      LINEAR_ISSUES+=("--linear-issue" "$2")
      shift 2
      ;;
    --linear-project)
      LINEAR_PROJECT="$2"
      shift 2
      ;;
    --linear-filter)
      LINEAR_FILTER="$2"
      shift 2
      ;;
    --linear-api-key)
      LINEAR_API_KEY="$2"
      shift 2
      ;;
    -e|--effort)
      EFFORT="$2"
      shift 2
      ;;
    --format)
      FORMAT="$2"
      shift 2
      ;;
    --codex)
      CODEX_OVERRIDES+=("--codex" "$2")
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
      ISSUE_ARGS+=("$1")
      shift
      ;;
  esac
done

CMD=(npx @openai/codex-security patch)

if [[ -n "${SCAN_ID}" ]]; then
  CMD+=("--scan" "${SCAN_ID}")
fi

if [[ -n "${SEVERITY}" ]]; then
  if [[ ! "${SEVERITY}" =~ ^(critical|high|medium|low)$ ]]; then
    echo "Error: --severity must be one of: critical, high, medium, low" >&2
    exit 2
  fi
  CMD+=("--severity" "${SEVERITY}")
fi

if [[ "${CREATE_PR}" == "true" ]]; then
  CMD+=("--create-pr")
fi

if [[ -n "${RESUME_PR}" ]]; then
  CMD+=("--resume-pr" "${RESUME_PR}")
fi

if [[ ${#LINEAR_ISSUES[@]} -gt 0 ]]; then
  CMD+=("${LINEAR_ISSUES[@]}")
fi

if [[ -n "${LINEAR_PROJECT}" ]]; then
  CMD+=("--linear-project" "${LINEAR_PROJECT}")
fi

if [[ -n "${LINEAR_FILTER}" ]]; then
  CMD+=("--linear-filter" "${LINEAR_FILTER}")
fi

if [[ -n "${LINEAR_API_KEY}" ]]; then
  CMD+=("--linear-api-key" "${LINEAR_API_KEY}")
fi

if [[ -n "${EFFORT}" ]]; then
  if [[ ! "${EFFORT}" =~ ^(minimal|low|medium|high|xhigh|max)$ ]]; then
    echo "Error: --effort must be one of: minimal, low, medium, high, xhigh, max" >&2
    exit 2
  fi
  CMD+=("--effort" "${EFFORT}")
fi

if [[ -n "${FORMAT}" ]]; then
  CMD+=("--format" "${FORMAT}")
fi

if [[ ${#CODEX_OVERRIDES[@]} -gt 0 ]]; then
  CMD+=("${CODEX_OVERRIDES[@]}")
fi

if [[ ${#ISSUE_ARGS[@]} -gt 0 ]]; then
  CMD+=("${ISSUE_ARGS[@]}")
fi

echo "============================================================"
echo "Codex Security: Patch Synthesis & Verification"
echo "Command: ${CMD[*]}"
echo "============================================================"

set +e
"${CMD[@]}"
EXIT_CODE=$?
set -e

exit "${EXIT_CODE}"
