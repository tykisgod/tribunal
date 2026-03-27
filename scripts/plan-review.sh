#!/usr/bin/env bash
# plan-review.sh — Send a design document to Codex CLI for review
#
# Usage:
#   ./scripts/plan-review.sh <document>                    # Default review
#   ./scripts/plan-review.sh <document> "custom prompt"    # Custom prompt
#
# Output:
#   Review saved to <document_name>_review.md (same directory)
#   Also printed to stdout

set -euo pipefail

DOC_FILE="${1:?Usage: $0 <document> [custom_prompt]}"
CUSTOM_PROMPT="${2:-}"

if [[ ! -f "$DOC_FILE" ]]; then
  echo "Error: file not found: $DOC_FILE" >&2
  exit 1
fi

if ! command -v codex &>/dev/null; then
  echo "Error: codex CLI not found. Install with: npm install -g @openai/codex" >&2
  exit 1
fi

# Output file: foo.md -> foo_review.md
DIR=$(dirname "$DOC_FILE")
BASE=$(basename "$DOC_FILE" .md)
REVIEW_FILE="${DIR}/${BASE}_review.md"

# Read CLAUDE.md if present (for project coding standards)
CODING_STANDARDS=""
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
if [[ -f "$PROJECT_ROOT/CLAUDE.md" ]]; then
  CODING_STANDARDS=$(cat "$PROJECT_ROOT/CLAUDE.md")
fi

# Build review prompt
if [[ -n "$CUSTOM_PROMPT" ]]; then
  REVIEW_PROMPT="$CUSTOM_PROMPT"
else
  REVIEW_PROMPT="Review the following design document / implementation plan.

Review criteria:
1. Architecture: Is the design clean, well-decoupled, and maintainable?
2. Correctness: Are there logical flaws, contradictions, or missing edge cases?
3. Completeness: Are there missing call sites, migration steps, or integration points?
4. Feasibility: Can this be implemented as described without hidden blockers?

Classify each finding by severity: [Critical] [Medium] [Suggestion]
For anything you're unsure about, mark it [Uncertain] — do NOT guess.
Be concise. Only output review findings, nothing else."
fi

DOC_CONTENT=$(cat "$DOC_FILE")

FULL_PROMPT="${REVIEW_PROMPT}"

if [[ -n "$CODING_STANDARDS" ]]; then
  FULL_PROMPT="${FULL_PROMPT}

---

## Project Standards (from CLAUDE.md)

${CODING_STANDARDS}"
fi

FULL_PROMPT="${FULL_PROMPT}

---

## Document Under Review

${DOC_CONTENT}"

echo ">>> Sending ${DOC_FILE} to Codex for review..." >&2

codex exec --sandbox read-only "$FULL_PROMPT" | tee "$REVIEW_FILE"

echo "" >&2
echo ">>> Review saved to: ${REVIEW_FILE}" >&2
