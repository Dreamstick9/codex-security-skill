#!/usr/bin/env bash
# ==============================================================================
# compare_scans.sh - Compare, match, and inspect Codex Security scans
# ==============================================================================
# Usage: ./scripts/compare_scans.sh <action> [options]
# Actions: list, show, logs, compare, match, rerun
# Exit codes: 0 success, 2 error / usage
# ==============================================================================

set -euo pipefail

usage() {
  cat <<EOF >&2
Usage: $(basename "$0") <action> [arguments] [options]

Actions:
  list [repo]                   List saved scans for repository
  show <scan_id>                Show scan configuration and findings summary
  logs <scan_id>                Read activity logs for a scan
  compare <before_id> <after_id> Match & compare findings and coverage between scans
  match <before_id> <after_id>  Match findings by root cause across scans (--all, --force)
  rerun <scan_id>               Rerun a saved scan with original config

Global Options:
  --format <fmt>                CLI output format (toon|json|yaml|md|jsonl)
  --filter-output <keys>        Filter output keys
  -h, --help                    Show this help message

Examples:
  $(basename "$0") list .
  $(basename "$0") show latest --show-linked-findings
  $(basename "$0") logs latest
  $(basename "$0") compare scan_001 scan_002
  $(basename "$0") match --all
  $(basename "$0") rerun latest
EOF
  exit 2
}

if [[ $# -lt 1 ]]; then
  usage
fi

ACTION="$1"
shift

case "${ACTION}" in
  list|show|logs|compare|match|rerun)
    npx @openai/codex-security scans "${ACTION}" "$@"
    ;;
  -h|--help)
    usage
    ;;
  *)
    echo "Unknown scans action: ${ACTION}" >&2
    usage
    ;;
esac
