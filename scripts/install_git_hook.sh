#!/usr/bin/env bash
# ==============================================================================
# install_git_hook.sh - Install a Git pre-commit security scan hook
# ==============================================================================
# Usage: ./scripts/install_git_hook.sh [options] [repository_path]
# Exit codes: 0 success, 2 error / usage
# ==============================================================================

set -euo pipefail

usage() {
  cat <<EOF >&2
Usage: $(basename "$0") [options] [repository_path]

Options:
  -f, --fail-on <severity>   Block commits for findings at or above level (critical|high|medium|low, default: high)
  -h, --help                 Show this help message

Examples:
  $(basename "$0") .
  $(basename "$0") --fail-on critical /path/to/repo
EOF
  exit 2
}

REPO_PATH="."
FAIL_ON="high"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -f|--fail-on)
      FAIL_ON="$2"
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

if [[ ! "${FAIL_ON}" =~ ^(critical|high|medium|low)$ ]]; then
  echo "Error: --fail-on must be one of: critical, high, medium, low" >&2
  exit 2
fi

REPO_PATH="$(cd "${REPO_PATH}" && pwd)"

echo "Installing Git pre-commit hook in ${REPO_PATH} (blocking on ${FAIL_ON}+ findings)..."
npx @openai/codex-security install-hook "${REPO_PATH}" --fail-on-severity "${FAIL_ON}"
echo "✓ Pre-commit security hook installed successfully."
