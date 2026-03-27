#!/usr/bin/env bash
# install.sh — Install Tribunal review skills into your Claude Code project
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)

echo "Installing Tribunal to: $PROJECT_ROOT"

mkdir -p "$PROJECT_ROOT/.claude/commands"
mkdir -p "$PROJECT_ROOT/scripts"

cp "$SCRIPT_DIR/commands/tribunal-plan.md" "$PROJECT_ROOT/.claude/commands/"
cp "$SCRIPT_DIR/commands/tribunal-code.md" "$PROJECT_ROOT/.claude/commands/"
cp "$SCRIPT_DIR/scripts/plan-review.sh" "$PROJECT_ROOT/scripts/"
cp "$SCRIPT_DIR/scripts/code-review.sh" "$PROJECT_ROOT/scripts/"
chmod +x "$PROJECT_ROOT/scripts/plan-review.sh"
chmod +x "$PROJECT_ROOT/scripts/code-review.sh"

echo ""
echo "Installed successfully!"
echo ""
echo "Skills added:"
echo "  /tribunal-plan  — Design document review with cross-model verification"
echo "  /tribunal-code  — Code review with cross-model verification"
echo ""
echo "Prerequisites:"
echo "  - Claude Code (claude)"
echo "  - Codex CLI (codex) — npm install -g @openai/codex"
echo ""
echo "Usage: in Claude Code, type /tribunal-plan or /tribunal-code"
