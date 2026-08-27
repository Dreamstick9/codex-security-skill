#!/usr/bin/env bash
# ==============================================================================
# validate_finding.sh - Validate candidate security findings using Codex Security
# ==============================================================================
# Usage: ./scripts/validate_finding.sh [options] <finding_file_or_text...>
# Exit codes: 0 success, 2 error / usage
# ==============================================================================

set -euo pipefail

usage() {
  cat <<EOF >&2
Usage: $(basename "$0") [options] <finding_file_or_text...>

Arguments:
  finding_file_or_text   Path to a finding file (JSON, Markdown, text) or inline text describing the finding.

Options:
  -e, --effort <level>   Reasoning effort (minimal|low|medium|high|xhigh|max, default: xhigh)
  --format <fmt>         CLI output format (toon|json|yaml|md|jsonl, default: toon)
  --codex <key=val>      Codex config override (e.g. model="gpt-5.6-terra")
  -h, --help             Show this help message

Examples:
  $(basename "$0") /tmp/finding_candidate.json
  $(basename "$0") "SQL Injection in src/api/user.ts:45 where req.params.id is concatenated into db.query"
  $(basename "$0") --effort max --format json /tmp/finding_candidate.json
  cat finding.md | $(basename "$0") -
EOF
  exit 2
}

if [[ $# -lt 1 ]]; then
  usage
fi

EFFORT=""
FORMAT=""
CODEX_OVERRIDES=()
FINDINGS_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
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
      FINDINGS_ARGS+=("$1")
      shift
      ;;
  esac
done

if [[ ${#FINDINGS_ARGS[@]} -eq 0 ]]; then
  echo "Error: No finding file or text provided." >&2
  usage
fi

# Build npx command
CMD=(npx @openai/codex-security validate)

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

# Check if reading from stdin
if [[ "${FINDINGS_ARGS[0]}" == "-" ]]; then
  TMP_INPUT="/tmp/codex_sec_finding_stdin_${TIMESTAMP:-$(date +%s%N)}.txt"
  cat > "${TMP_INPUT}"
  CMD+=("${TMP_INPUT}")
else
  CMD+=("${FINDINGS_ARGS[@]}")
fi

echo "============================================================"
echo "Codex Security: Validating Finding(s)"
echo "Command: ${CMD[*]}"
echo "============================================================"

set +e
"${CMD[@]}"
EXIT_CODE=$?
set -e

# Cleanup temporary stdin file if created
if [[ -n "${TMP_INPUT:-}" && -f "${TMP_INPUT}" ]]; then
  rm -f "${TMP_INPUT}"
fi

exit "${EXIT_CODE}"
