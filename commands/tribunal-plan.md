Review a design document using cross-model verification. Sends the document to Codex for review, independently verifies each finding against source code, then iterates until no critical issues remain (max 5 rounds).

User can provide: a file path. If not specified, reviews the most recently discussed design in the conversation.

## Execution Flow

### 1. Determine Target File
In order of priority:
1. If the user specified a file path, use it
2. If there's a plan file from the current conversation (e.g., under `Docs/`), use the latest one
3. If neither exists, review the current conversation context — find the most recent design discussion, write it to a temp spec file (`Docs/tmp-review-spec_<YYYYMMDD-HHmm>.md`), then review that file
4. Fallback: `ls -t Docs/**/*.md | head -1`

### 2-6. Automated Review Loop

**Loop automatically — do not ask the user between rounds.** Stop when either:
- No `[Critical]` issues in the Codex review
- 5 rounds completed

Each round:

#### 2a. Send to Codex for Review
Run in background using Bash tool with `run_in_background: true`:
```bash
./scripts/plan-review.sh <file_path>
```
The script calls `codex exec --sandbox read-only`. Results go to stdout and `<filename>_review.md`.
It automatically reads `CLAUDE.md` for project coding standards.
Codex review typically takes 5-10 minutes. The system will notify when complete.
Tell the user the background task has been submitted. Continue other work while waiting.

#### 2b. Read and Summarize Review Results
Read `<filename>_review.md` and classify by severity:
- **Critical**: Must-fix logic flaws, contradictions, or major design defects
- **Medium**: Worth improving but non-blocking
- **Suggestion**: Nice-to-have optimizations

Show the summary to the user. **Do NOT modify the document yet — verify first.**

#### 2c. Independent Verification (REQUIRED)
For each Critical and Medium finding, **read the source code referenced in the review** to independently verify:
- Read the files and line numbers Codex mentioned — confirm descriptions match actual code
- For data/config claims (values, thresholds, formulas), read the original files to verify
- Tag each finding: **Confirmed** (code proves it) / **Rejected** (code doesn't support the conclusion) / **Partially confirmed** (needs nuance)

Show verification results to the user with evidence (file paths and key code excerpts).

#### 2d. Modify the Design Document
- Only fix **verified/confirmed** issues — skip rejected ones
- For each confirmed Critical issue, modify the relevant section
- For confirmed Medium issues, fix at discretion
- Show a change summary to the user

#### 2e. Decide Whether to Continue
- Confirmed `[Critical]` issues were fixed this round → start next round (back to 2a)
- No `[Critical]` issues this round → output "Review passed" and end
- 5 rounds reached → output final status and end

Print `=== Round N/5 ===` at the start of each round.

## Key Principles
- **Never blindly trust Codex** — it may misread code, cite outdated info, or make assumptions. Every finding must be verified against source code before acting on it
- Do not change design intent — only fix issues the review found
- Keep document structure intact — only modify what needs changing
- Custom prompt: `./scripts/plan-review.sh <file> "custom review instructions"`
