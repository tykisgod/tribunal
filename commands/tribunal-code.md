Send current branch code changes to Codex CLI for review, then fix code based on verified findings. Supports multi-round iteration until no critical issues remain.

Arguments: $ARGUMENTS
- No arguments: diff against develop...HEAD
- `--base <branch>`: specify comparison base branch
- `--commits`: only review the latest commit
- `--ext "*.py"`: filter by file extension

## Execution Flow

### 1. Send to Codex for Review
Run in background using Bash tool with `run_in_background: true`:
```bash
./scripts/code-review.sh $ARGUMENTS
```
The script calls `codex exec --sandbox read-only`. Results go to stdout and `Docs/<branch>/codex-code-review_<timestamp>.md`.
Codex review typically takes 5-10 minutes. The system will notify when complete.
Tell the user the background task has been submitted. Continue other work while waiting.

### 2. Read and Summarize Review Results
Read the output file and classify by severity:
- **Critical**: Must-fix bugs, architecture violations, anti-patterns
- **Medium**: Worth improving but non-blocking
- **Suggestion**: Nice-to-have optimizations

Show the summary to the user.

### 3. Independent Verification (REQUIRED)
For each Critical and Medium finding, **read the actual source code** to verify:
- Check if the files and line numbers Codex cited actually contain the described issue
- Verify claims about data flow, dependencies, or behavior by reading the code
- Tag each: **Confirmed** / **Rejected** / **Partially confirmed**

**Over-engineering check:** For each confirmed finding, also evaluate whether the implied fix is proportional:
- Does the suggestion add unnecessary abstraction, indirection, or configurability?
- Would a simpler, more direct fix solve the same problem?
- Is the suggestion chasing code purity (splitting files, renaming namespaces, adding generics) without meaningful architectural benefit?

Tag disproportionate suggestions as **Confirmed but over-engineered** — acknowledge the real issue but propose a simpler fix.

Show verification results with evidence. Ask the user whether to proceed with fixes.

### 4. Fix Code
- For each **confirmed Critical** issue, locate and fix the code
- For findings tagged **Confirmed but over-engineered**, apply the simpler alternative fix, not Codex's original suggestion
- For confirmed **Medium** issues the user approves, fix at discretion
- Run compilation/tests after each fix to verify
- Show a change summary when done

### 5. Iterate (Optional)
After fixes, ask the user if they want another round. If two consecutive rounds have no new Critical issues, suggest ending the loop.

**When running another round:** If the previous round identified over-engineered suggestions, pass a custom prompt that includes this context:
```bash
./scripts/code-review.sh --prompt "Review these code changes. In the previous round, the following suggestions were deemed over-engineered and simpler fixes were applied instead: <list the items and reasoning>. Focus on whether the simpler fixes are correct. Do not re-suggest the more complex approaches unless the simpler version introduces a real defect. Classify findings as [Critical] [Medium] [Suggestion]."
```
This prevents Codex from re-proposing the same over-engineered solutions.

## Key Principles
- **Never blindly accept Codex feedback** — it may misread code, cite wrong lines, or make assumptions. Every finding must be verified against actual source code before acting on it
- **Guard against over-engineering** — Codex tends to suggest maximally "pure" solutions (extra layers, file splits, generics). Always ask: "is the fix proportional to the problem?" If not, choose the simpler path and tell Codex why in the next round
- Only address actual issues identified in review — don't refactor surrounding code
- Custom prompt: `./scripts/code-review.sh --prompt "custom review instructions"`
