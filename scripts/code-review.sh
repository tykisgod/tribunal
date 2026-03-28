#!/usr/bin/env bash
# code-review.sh — Send code changes to Codex CLI for review
#
# Usage:
#   ./scripts/code-review.sh                           # Default: develop...HEAD
#   ./scripts/code-review.sh --base main               # Custom base branch
#   ./scripts/code-review.sh --commits                 # Last commit only
#   ./scripts/code-review.sh --ext "*.py"              # Filter by extension
#   ./scripts/code-review.sh --prompt "custom prompt"  # Custom prompt
#
# Output:
#   Review saved to Docs/<branch>/codex-code-review_<timestamp>.md
#   Also printed to stdout

set -euo pipefail

if ! command -v codex &>/dev/null; then
  echo "Error: codex CLI not found. Install with: npm install -g @openai/codex" >&2
  exit 1
fi

BASE_BRANCH="develop"
MODE="branch"
EXT_FILTER=""
CUSTOM_PROMPT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base)    BASE_BRANCH="$2"; shift 2 ;;
    --commits) MODE="commits"; shift ;;
    --ext)     EXT_FILTER="$2"; shift 2 ;;
    --prompt)  CUSTOM_PROMPT="$2"; shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

# Validate base branch looks like a git ref (prevent flag injection)
if [[ "$BASE_BRANCH" == -* ]]; then
  echo "Error: invalid base branch: $BASE_BRANCH" >&2
  exit 1
fi

# Build diff command args
DIFF_ARGS=()
if [[ -n "$EXT_FILTER" ]]; then
  DIFF_ARGS+=(-- "$EXT_FILTER")
fi

case "$MODE" in
  branch)
    DIFF=$(git diff "${BASE_BRANCH}...HEAD" "${DIFF_ARGS[@]+"${DIFF_ARGS[@]}"}")
    DIFF_DESC="${BASE_BRANCH}...HEAD"
    ;;
  commits)
    DIFF=$(git diff "HEAD~1...HEAD" "${DIFF_ARGS[@]+"${DIFF_ARGS[@]}"}")
    DIFF_DESC="HEAD~1...HEAD"
    ;;
esac

if [[ -z "$DIFF" ]]; then
  echo "No code changes found (${DIFF_DESC})" >&2
  exit 0
fi

# Output file — sanitize branch name to prevent path traversal
BRANCH=$(git branch --show-current | sed 's|.*/||' | tr -cd 'a-zA-Z0-9_.-')
TIMESTAMP=$(date +"%Y-%m-%d-%H%M")
OUT_DIR="Docs/${BRANCH}"
mkdir -p "$OUT_DIR"
REVIEW_FILE="${OUT_DIR}/codex-code-review_${TIMESTAMP}.md"

# Write diff to temp file so Codex reads it from disk (avoids ARG_MAX)
DIFF_FILE=$(mktemp /tmp/code-review-diff-XXXXXXXX)
printf '%s' "$DIFF" > "$DIFF_FILE"

# Build review prompt
if [[ -n "$CUSTOM_PROMPT" ]]; then
  REVIEW_PROMPT="$CUSTOM_PROMPT"
else
  REVIEW_PROMPT="Review the following code changes.

Review criteria:
1. Bugs: Logic errors, off-by-one, null derefs, race conditions
2. Architecture: Dependency violations, coupling issues, layering breaks
3. Performance: O(N^2) in hot paths, unnecessary allocations, missing cleanup
4. Security: Injection, XSS, unsafe deserialization (if applicable)
5. Style: Violations of project coding standards (see below)

Classify each finding by severity: [Critical] [Medium] [Suggestion]
For each finding, cite the specific file and line range.
For anything you're unsure about, mark it [Uncertain] — do NOT guess.
Be concise. Only output review findings."
fi

# Tell Codex to read files from disk instead of inlining content
FULL_PROMPT="${REVIEW_PROMPT}

---

## Project Context

Read the CLAUDE.md file at the project root for coding standards.
Read the AGENTS.md file at the project root for architecture rules (if it exists).

---

## Code Changes (${DIFF_DESC})

Read ${DIFF_FILE} for the full diff."

echo ">>> Sending code changes (${DIFF_DESC}) to Codex for review..." >&2
echo ">>> Diff written to ${DIFF_FILE} ($(wc -l < "$DIFF_FILE") lines)" >&2

codex exec --sandbox read-only "$FULL_PROMPT" | tee "$REVIEW_FILE"

rm -f "$DIFF_FILE"

echo "" >&2
echo ">>> Review saved to: ${REVIEW_FILE}" >&2
