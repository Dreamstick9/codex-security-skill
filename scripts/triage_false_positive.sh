#!/usr/bin/env bash
# ==============================================================================
# triage_false_positive.sh - Helper script to mark a finding occurrence as false positive
# ==============================================================================

set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Usage: $(basename "$0") <occurrence_id> <reason_explanation>" >&2
  echo "Example: $(basename "$0") occ-123abc456 \"Parameter sanitized upstream by middleware\"" >&2
  exit 1
fi

OCCURRENCE_ID="$1"
REASON="$2"

echo "Triaging occurrence: ${OCCURRENCE_ID}"
echo "Reason: ${REASON}"

npx @openai/codex-security findings false-positive "${OCCURRENCE_ID}" --reason "${REASON}"

echo "Occurrence ${OCCURRENCE_ID} marked as false positive."
