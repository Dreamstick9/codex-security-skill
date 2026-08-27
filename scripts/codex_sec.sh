#!/usr/bin/env bash
# ==============================================================================
# codex_sec.sh - Unified CLI Entrypoint for Codex Security Toolkit
# ==============================================================================
# All-in-one CLI command wrapping @openai/codex-security operations.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<EOF
Codex Security CLI Wrapper

Usage: $(basename "$0") <command> [options]

Core Security Commands:
  scan [options] [path]        Run standard or deep security scan
  diff [ref] [options]         Run fast diff scan against git reference (default: HEAD~1 or origin/main)
  deep [options] [path]        Run multi-worker deep audit
  validate <file_or_text...>   Validate candidate security finding(s)
  patch [options]              Generate and verify security patches for open findings
  verify-fix [options]         Verify security fixes without modifying code
  triage <occ_id> <reason>     Mark finding occurrence as false positive
  export <scan_dir> [options]  Export completed scan findings to SARIF, JSON, or CSV
  compare <before> <after>     Match and compare findings between scan runs
  components [plan|run]        Generate monorepo component plans or run component scans
  bulk [options] [csv]         Execute bulk scans across multiple repositories
  hook [install]               Install Git pre-commit security check

System & Info Commands:
  scans <list|show|logs>       Inspect previous scan history and logs
  findings [list]              List open findings across scans for a repository
  auth <login|logout|status>   Manage ChatGPT / API key credentials
  doctor                       Verify local environment, Node.js, Python, and CLI setup
  info                         Show read-only SDK and plugin metadata
  help                         Show this help message

Run '$(basename "$0") <command> --help' for details on specific commands.
EOF
  exit "${1:-0}"
}

if [[ $# -lt 1 ]]; then
  usage 1
fi

COMMAND="$1"
shift

case "${COMMAND}" in
  scan)
    exec "${SCRIPT_DIR}/run_security_scan.sh" "$@"
    ;;
  diff)
    REF=""
    if [[ $# -ge 1 && ! "$1" =~ ^- ]]; then
      REF="$1"
      shift
    else
      if git rev-parse --verify origin/main >/dev/null 2>&1; then
        REF="origin/main"
      elif git rev-parse --verify HEAD~1 >/dev/null 2>&1; then
        REF="HEAD~1"
      else
        REF="HEAD"
      fi
    fi
    exec "${SCRIPT_DIR}/run_security_scan.sh" --diff "${REF}" "$@"
    ;;
  deep)
    exec "${SCRIPT_DIR}/run_security_scan.sh" --mode deep "$@"
    ;;
  validate)
    exec "${SCRIPT_DIR}/validate_finding.sh" "$@"
    ;;
  patch)
    exec "${SCRIPT_DIR}/patch_findings.sh" "$@"
    ;;
  verify-fix|verify_fix)
    exec "${SCRIPT_DIR}/verify_fix.sh" "$@"
    ;;
  triage)
    exec "${SCRIPT_DIR}/triage_false_positive.sh" "$@"
    ;;
  export)
    exec "${SCRIPT_DIR}/export_sarif.sh" "$@"
    ;;
  compare)
    exec "${SCRIPT_DIR}/compare_scans.sh" compare "$@"
    ;;
  components)
    exec "${SCRIPT_DIR}/scan_components.sh" "$@"
    ;;
  bulk)
    exec "${SCRIPT_DIR}/bulk_scan.sh" "$@"
    ;;
  hook)
    exec "${SCRIPT_DIR}/install_git_hook.sh" "$@"
    ;;
  scans)
    ACTION="${1:-list}"
    if [[ $# -ge 1 ]]; then shift; fi
    exec "${SCRIPT_DIR}/compare_scans.sh" "${ACTION}" "$@"
    ;;
  findings)
    ACTION="${1:-list}"
    if [[ $# -ge 1 && ! "$1" =~ ^- ]]; then shift; fi
    if [[ "${ACTION}" == "list" ]]; then
      npx @openai/codex-security findings list "$@"
    else
      npx @openai/codex-security findings "${ACTION}" "$@"
    fi
    ;;
  auth)
    ACTION="${1:-status}"
    if [[ $# -ge 1 ]]; then shift; fi
    if [[ "${ACTION}" == "status" ]]; then
      npx @openai/codex-security login status "$@"
    elif [[ "${ACTION}" == "login" ]]; then
      npx @openai/codex-security login "$@"
    elif [[ "${ACTION}" == "logout" ]]; then
      npx @openai/codex-security logout "$@"
    else
      npx @openai/codex-security login "${ACTION}" "$@"
    fi
    ;;
  info)
    npx @openai/codex-security info "$@"
    ;;
  doctor)
    echo "============================================================"
    echo "Codex Security Environment Diagnostic (Doctor)"
    echo "============================================================"
    
    # 1. Node.js
    if command -v node >/dev/null 2>&1; then
      NODE_VER="$(node -v)"
      echo "✓ Node.js: ${NODE_VER} ($(which node))"
    else
      echo "✗ Node.js: NOT FOUND (requires Node >= 22.13.0)"
    fi
    
    # 2. Python
    if command -v python3 >/dev/null 2>&1; then
      PY_VER="$(python3 --version 2>&1)"
      echo "✓ Python:  ${PY_VER} ($(which python3))"
    else
      echo "✗ Python:  NOT FOUND (requires Python >= 3.10)"
    fi
    
    # 3. NPX & Package Access
    if command -v npx >/dev/null 2>&1; then
      echo "✓ NPX:     $(which npx)"
      CLI_VER="$(npx @openai/codex-security --version 2>/dev/null || echo 'FAILED')"
      if [[ "${CLI_VER}" != "FAILED" ]]; then
        echo "✓ Codex Security CLI: v${CLI_VER}"
      else
        echo "✗ Codex Security CLI: Could not load via npx"
      fi
    else
      echo "✗ NPX:     NOT FOUND"
    fi
    
    # 4. Auth status
    echo "------------------------------------------------------------"
    echo "Authentication Check:"
    npx @openai/codex-security login status || true
    echo "============================================================"
    ;;
  -h|--help|help)
    usage 0
    ;;
  *)
    echo "Unknown command: ${COMMAND}" >&2
    usage 1
    ;;
esac
