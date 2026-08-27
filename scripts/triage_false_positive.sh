#!/usr/bin/env bash
# ==============================================================================
# triage_false_positive.sh - Mark a Codex Security occurrence as false positive
# ==============================================================================
# Verified: npx @openai/codex-security findings false-positive --help
# Usage: ./scripts/triage_false_positive.sh <occurrence_id> <reason_explanation>
# occurrenceId format: occ_[a-f0-9]{24} (see findings.json)
# Persisted to workbench DB; future scans on same repo suppress matching fingerprint.

set -euo pipefail

usage() {
  cat <<EOF >&2
Usage: $(basename "$0") <occurrence_id> <reason_explanation>

  occurrence_id   occ_[a-f0-9]{24} from findings.json (e.g., occ_a1b2c3d4...)
  reason          Explanation for dismissal (quoted; will be stored)

Examples:
  $(basename "$0") occ_a1b2c3d4e5f6a7b8c9d0e1f2 "Validated by API gateway Zod schema before sink."
  $(basename "$0") occ_abc123... "Dead code: handler not mounted in router."
  npx @openai/codex-security findings false-positive occ_... --reason "..."
  npx @openai/codex-security findings list . --format json | jq .findings

Notes:
  - Suppression is by fingerprint (codex-security/v1:sha256:...), so re-scans suppress re-introduction.
  - To re-open, delete the workbench ledger row or re-validate with 'reportable' disposition.
EOF
  exit 2
}

if [[ $# -lt 2 ]]; then usage; fi

OCCURRENCE_ID="$1"
REASON="$2"

if [[ ! "$OCCURRENCE_ID" =~ ^occ_[a-f0-9]{24}$ ]]; then
  echo "Warning: occurrenceId '$OCCURRENCE_ID' does not match occ_[a-f0-9]{24}; CLI may reject it." >&2
fi
if [[ ${#REASON} -lt 10 ]]; then
  echo "Warning: reason is very short; provide 1-2 sentences citing the control (middleware, authz, dead code)." >&2
fi

echo "Triaging occurrence: ${OCCURRENCE_ID}"
echo "Reason: ${REASON}"
echo ""

if ! npx @openai/codex-security findings false-positive "${OCCURRENCE_ID}" --reason "${REASON}"; then
  EC=$?
  echo "" >&2
  echo "Failed (exit $EC). Verify occurrenceId exists:" >&2
  echo "  npx @openai/codex-security findings list . --format json | jq '.findings[] | {occ: .occurrenceId, title}'" >&2
  exit $EC
fi

echo ""
echo "✓ Occurrence ${OCCURRENCE_ID} marked as false positive (suppressed)."
echo "  Future scans will treat matching fingerprint as suppressed."
