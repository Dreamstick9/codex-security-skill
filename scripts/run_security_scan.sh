#!/usr/bin/env bash
# ==============================================================================
# run_security_scan.sh - Safe wrapper for Codex Security scans (0.1.20)
# ==============================================================================
# Verified against: npx @openai/codex-security scan --help, info, --dry-run
# Defaults: model gpt-5.6-sol, effort xhigh, provider openai, mode standard
# Isolation: output dir must be OUTSIDE repo, mkdir 700, --archive-existing support
# CI: --headless auto-enabled when CI or NO_TTY, --dry-run no cost

set -euo pipefail

usage() {
  cat <<EOF
Usage: $(basename "$0") [options] [repository_path]

Options:
  -m, --mode <standard|deep>         Scan mode (default: standard)
  -p, --path <subpath>               Scope to subpath (repeatable)
  -d, --diff <git-ref>               Scan committed diff against ref (e.g., origin/main)
  -w, --working-tree                 Scan uncommitted working tree changes
  -k, --knowledge-base <path>        Include threat model/policy file (repeatable)
      --scan-prompt-file <path>      Append scan instructions from file
      --validation-prompt-file <path> Replace final validation workflow (non-deep)
      --post-scan-prompt-file <path> Run after each scan
  -c, --max-cost <usd>               Max estimated cost in USD (e.g., 15.00)
      --max-time-hours <hours>       Max deep hours (up to 96)
      --stop-after-no-new <n>        Stop deep after N no-new runs
      --max-discovery-runs <n>       Max deep discovery runs
  -f, --fail-on <severity>           Exit 1 if findings >= severity (critical|high|medium|low)
  -o, --output-dir <dir>             Custom output dir (default: isolated /tmp)
      --archive-existing             Archive existing results (requires --output-dir)
  -e, --effort <lvl>                 Reasoning effort (minimal|low|medium|high|xhigh|max)
      --model <name>                 Override model (default: gpt-5.6-sol)
      --provider <name>              Provider (openai|openrouter|fireworks|amazon-bedrock)
      --patch                        Patch + verify findings inline
      --patch-severity <lvl>         Patch threshold (requires --patch)
      --create-pr                    Create draft PR after verified patches
      --headless                     Force plain-text progress
      --dry-run                      Validate inputs without running (no cost)
      --verbose                      Diagnostics to stderr
  -h, --help                         Show this help

Examples:
  $(basename "$0") .
  $(basename "$0") --diff origin/main --fail-on high .
  $(basename "$0") --mode deep --max-cost 15.00 --output-dir /tmp/my-scan /path/to/project
  $(basename "$0") --dry-run .
  $(basename "$0") --patch --patch-severity high --create-pr .

Artifacts: findings.json, coverage.json, scan-manifest.json, report.md, findings/<id>/<id>.md
Exit codes: 0 clean, 1 gate tripped, 2 error, 130 SIGINT, 143 SIGTERM
EOF
  exit "${1:-1}"
}

# ---------- defaults ----------
MODE="standard"
FAIL_ON=""
DIFF_REF=""
WORKING_TREE=false
MAX_COST=""
MAX_TIME_HOURS=""
STOP_AFTER_NO_NEW=""
MAX_DISCOVERY_RUNS=""
OUTPUT_DIR=""
ARCHIVE_EXISTING=false
EFFORT=""
MODEL=""
PROVIDER=""
PATCH=false
PATCH_SEVERITY=""
HEADLESS=false
DRY_RUN=false
VERBOSE=false
PATHS=()
KB_PATHS=()
SCAN_PROMPT_FILE=""
VALIDATION_PROMPT_FILE=""
POST_SCAN_PROMPT_FILE=""

# ---------- arg parsing ----------
REPO_PATH=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -m|--mode) MODE="$2"; shift 2 ;;
    -p|--path) PATHS+=("--path" "$2"); shift 2 ;;
    -d|--diff) DIFF_REF="$2"; shift 2 ;;
    -w|--working-tree) WORKING_TREE=true; shift ;;
    -k|--knowledge-base) KB_PATHS+=("--knowledge-base" "$2"); shift 2 ;;
    --scan-prompt-file) SCAN_PROMPT_FILE="$2"; shift 2 ;;
    --validation-prompt-file) VALIDATION_PROMPT_FILE="$2"; shift 2 ;;
    --post-scan-prompt-file) POST_SCAN_PROMPT_FILE="$2"; shift 2 ;;
    -c|--max-cost) MAX_COST="$2"; shift 2 ;;
    --max-time-hours) MAX_TIME_HOURS="$2"; shift 2 ;;
    --stop-after-no-new) STOP_AFTER_NO_NEW="$2"; shift 2 ;;
    --max-discovery-runs) MAX_DISCOVERY_RUNS="$2"; shift 2 ;;
    -f|--fail-on) FAIL_ON="$2"; shift 2 ;;
    -o|--output-dir) OUTPUT_DIR="$2"; shift 2 ;;
    --archive-existing) ARCHIVE_EXISTING=true; shift ;;
    -e|--effort) EFFORT="$2"; shift 2 ;;
    --model) MODEL="$2"; shift 2 ;;
    --provider) PROVIDER="$2"; shift 2 ;;
    --patch) PATCH=true; shift ;;
    --patch-severity) PATCH_SEVERITY="$2"; shift 2 ;;
    --headless) HEADLESS=true; shift ;;
    --dry-run) DRY_RUN=true; shift ;;
    --verbose) VERBOSE=true; shift ;;
    -h|--help) usage 0 ;;
    --) REPO_PATH="${2:-.}"; shift 2; break ;;
    -*) echo "Unknown option: $1" >&2; usage 2 ;;
    *) 
      if [[ -n "$REPO_PATH" ]]; then echo "Multiple repositories given: $REPO_PATH and $1" >&2; usage 2; fi
      REPO_PATH="$1"; shift ;;
  esac
done

REPO_PATH="${REPO_PATH:-.}"
if [[ ! -e "$REPO_PATH" ]]; then echo "Error: repository path '$REPO_PATH' does not exist." >&2; exit 2; fi
REPO_PATH="$(cd "${REPO_PATH}" && pwd)"
REPO_NAME="$(basename "${REPO_PATH}")"

# ---------- preflight: node/python, output isolation ----------
if ! command -v node >/dev/null 2>&1; then echo "Error: node not found (requires ^22.13.0)." >&2; exit 2; fi
NODE_MAJOR="$(node -p 'process.versions.node.split(".")[0]')"
if [[ "$NODE_MAJOR" -lt 22 ]]; then echo "Warning: node $NODE_MAJOR may be too old; need ^22.13.0 (see package.json#engines)." >&2; fi
if ! command -v npx >/dev/null 2>&1; then echo "Error: npx not found." >&2; exit 2; fi
if ! npx --yes @openai/codex-security --version >/dev/null 2>&1; then
  echo "Error: failed to run 'npx @openai/codex-security --version'. Check network/npm." >&2
  exit 2
fi
# Python 3.10+ (Codex Security plugin requires it)
if command -v python3 >/dev/null 2>&1; then
  if ! python3 -c 'import sys; raise SystemExit(0 if sys.version_info >= (3,10) else 1)' 2>/dev/null; then
    echo "Warning: python3 <3.10 detected; scan requires Python 3.10+ (use --python)." >&2
  fi
else
  echo "Warning: python3 not found; plugin will try to discover Python automatically." >&2
fi

# Output dir: outside repo, empty unless --archive-existing
if [[ -z "${OUTPUT_DIR}" ]]; then
  TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
  OUTPUT_DIR="/tmp/codex-security-scans/${REPO_NAME}_${TIMESTAMP}"
fi
# Canonicalize for ancestry check
mkdir -p "$(dirname "${OUTPUT_DIR}")"
# Resolve to absolute if possible
OUTPUT_DIR_ABS="$(python3 -c 'import os,sys; print(os.path.abspath(sys.argv[1]))' "${OUTPUT_DIR}" 2>/dev/null || echo "${OUTPUT_DIR}")"
REPO_ABS="$(python3 -c 'import os,sys; print(os.path.abspath(sys.argv[1]))' "${REPO_PATH}" 2>/dev/null || echo "${REPO_PATH}")"
if [[ "${OUTPUT_DIR_ABS}" == "${REPO_ABS}" ]] || [[ "${OUTPUT_DIR_ABS}" == "${REPO_ABS}/"* ]]; then
  echo "Error: --output-dir must be OUTSIDE repository." >&2
  echo "  repo:   ${REPO_ABS}" >&2
  echo "  output: ${OUTPUT_DIR_ABS}" >&2
  exit 2
fi
if [[ -e "${OUTPUT_DIR}" && -n "$(ls -A "${OUTPUT_DIR}" 2>/dev/null)" && "${ARCHIVE_EXISTING}" != "true" ]]; then
  echo "Error: output dir '${OUTPUT_DIR}' exists and is not empty. Use --archive-existing or choose empty dir." >&2
  exit 2
fi
mkdir -p "${OUTPUT_DIR}"
chmod 700 "${OUTPUT_DIR}"

# ---------- validate flag values ----------
if [[ "${MODE}" != "standard" && "${MODE}" != "deep" ]]; then echo "Error: --mode must be standard|deep" >&2; exit 2; fi
if [[ -n "${FAIL_ON}" && ! "${FAIL_ON}" =~ ^(critical|high|medium|low)$ ]]; then echo "Error: --fail-on must be critical|high|medium|low" >&2; exit 2; fi
if [[ -n "${EFFORT}" && ! "${EFFORT}" =~ ^(minimal|low|medium|high|xhigh|max)$ ]]; then echo "Error: --effort must be minimal|low|medium|high|xhigh|max" >&2; exit 2; fi
if [[ "${PATCH}" == "true" && -n "${PATCH_SEVERITY}" && ! "${PATCH_SEVERITY}" =~ ^(critical|high|medium|low)$ ]]; then echo "Error: --patch-severity must be critical|high|medium|low" >&2; exit 2; fi
if [[ "${PATCH}" == "false" && -n "${PATCH_SEVERITY}" ]]; then echo "Error: --patch-severity requires --patch" >&2; exit 2; fi

# Auto-headless in CI / non-TTY
if [[ -n "${CI:-}" || ! -t 1 ]]; then HEADLESS=true; fi

# ---------- build command ----------
CMD=(npx @openai/codex-security scan "${REPO_PATH}" --output-dir "${OUTPUT_DIR}" --mode "${MODE}")

if [[ ${#PATHS[@]} -gt 0 ]]; then CMD+=("${PATHS[@]}"); fi
if [[ -n "${DIFF_REF}" ]]; then CMD+=("--diff" "${DIFF_REF}"); fi
if [[ "${WORKING_TREE}" == "true" ]]; then CMD+=("--working-tree"); fi
if [[ ${#KB_PATHS[@]} -gt 0 ]]; then CMD+=("${KB_PATHS[@]}"); fi
if [[ -n "${SCAN_PROMPT_FILE}" ]]; then CMD+=("--scan-prompt-file" "${SCAN_PROMPT_FILE}"); fi
if [[ -n "${VALIDATION_PROMPT_FILE}" ]]; then CMD+=("--validation-prompt-file" "${VALIDATION_PROMPT_FILE}"); fi
if [[ -n "${POST_SCAN_PROMPT_FILE}" ]]; then CMD+=("--post-scan-prompt-file" "${POST_SCAN_PROMPT_FILE}"); fi
if [[ -n "${MAX_COST}" ]]; then CMD+=("--max-cost" "${MAX_COST}"); fi
if [[ -n "${MAX_TIME_HOURS}" ]]; then CMD+=("--max-time-hours" "${MAX_TIME_HOURS}"); fi
if [[ -n "${STOP_AFTER_NO_NEW}" ]]; then CMD+=("--stop-after-no-new" "${STOP_AFTER_NO_NEW}"); fi
if [[ -n "${MAX_DISCOVERY_RUNS}" ]]; then CMD+=("--max-discovery-runs" "${MAX_DISCOVERY_RUNS}"); fi
if [[ -n "${FAIL_ON}" ]]; then CMD+=("--fail-on-severity" "${FAIL_ON}"); fi
if [[ -n "${EFFORT}" ]]; then CMD+=("--effort" "${EFFORT}"); fi
if [[ -n "${MODEL}" ]]; then CMD+=("--model" "${MODEL}"); fi
if [[ -n "${PROVIDER}" ]]; then CMD+=("--provider" "${PROVIDER}"); fi
if [[ "${PATCH}" == "true" ]]; then CMD+=("--patch"); fi
if [[ -n "${PATCH_SEVERITY}" ]]; then CMD+=("--patch-severity" "${PATCH_SEVERITY}"); fi
# --create-pr is only valid with --patch, but CLI tolerates it; we keep explicit check
if [[ "${PATCH}" == "true" && -n "${CREATE_PR:-}" ]]; then CMD+=("--create-pr"); fi
if [[ "${ARCHIVE_EXISTING}" == "true" ]]; then CMD+=("--archive-existing"); fi
if [[ "${HEADLESS}" == "true" ]]; then CMD+=("--headless"); fi
if [[ "${DRY_RUN}" == "true" ]]; then CMD+=("--dry-run"); fi
if [[ "${VERBOSE}" == "true" ]]; then CMD+=("--verbose"); fi

echo "============================================================"
echo "Codex Security Scan (0.1.20)"
echo "Repository: ${REPO_PATH}"
echo "Mode:       ${MODE}"
echo "Output Dir: ${OUTPUT_DIR} (chmod 700)"
if [[ "${DRY_RUN}" == "true" ]]; then echo "Dry Run:    yes (no cost)"; fi
if [[ -n "${FAIL_ON}" ]]; then echo "Fail On:    ${FAIL_ON}+"; fi
echo "Command:    ${CMD[*]}"
echo "============================================================"

set +e
"${CMD[@]}"
SCAN_EXIT_CODE=$?
set -e

echo ""
echo "============================================================"
# Map exit codes for humans
if [[ $SCAN_EXIT_CODE -eq 0 ]]; then echo "Scan finished: SUCCESS (no gate tripped)";
elif [[ $SCAN_EXIT_CODE -eq 1 ]]; then echo "Scan finished: GATE TRIPPED (findings >= --fail-on-severity)";
elif [[ $SCAN_EXIT_CODE -eq 2 ]]; then echo "Scan finished: ERROR (bad args / missing deps)";
elif [[ $SCAN_EXIT_CODE -eq 130 ]]; then echo "Scan interrupted (SIGINT)";
elif [[ $SCAN_EXIT_CODE -eq 143 ]]; then echo "Scan terminated (SIGTERM)";
else echo "Scan finished: exit $SCAN_EXIT_CODE"; fi
echo "Artifacts:  ${OUTPUT_DIR}"
for f in report.md findings.json coverage.json scan-manifest.json; do
  [[ -f "${OUTPUT_DIR}/${f}" ]] && echo "  - ${OUTPUT_DIR}/${f}"
done
if [[ -d "${OUTPUT_DIR}/findings" ]]; then echo "  - ${OUTPUT_DIR}/findings/<id>/<id>.md (per-finding writeups)"; fi
SIBLING_SARIF="$(dirname "${OUTPUT_DIR}")/$(basename "${OUTPUT_DIR}").sarif"
 echo "Next: export SARIF via ./scripts/export_sarif.sh \"${OUTPUT_DIR}\" --source-root \"${REPO_PATH}\"  or  npx @openai/codex-security export \"${OUTPUT_DIR}\" --export-format sarif --output \"${SIBLING_SARIF}\" --source-root \"${REPO_PATH}\""
echo "      triage via ./scripts/triage_false_positive.sh <occ-id> \"reason\"  or  npx @openai/codex-security findings false-positive <occ> --reason \"...\""
echo "============================================================"

exit "${SCAN_EXIT_CODE}"
