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

Show verification results with evidence. Ask the user whether to proceed with fixes.

### 4. Fix Code
- For each **confirmed Critical** issue, locate and fix the code
- For confirmed **Medium** issues the user approves, fix at discretion
- Run compilation/tests after each fix to verify
- Show a change summary when done

### 5. Iterate (Optional)
After fixes, ask the user if they want another round. If two consecutive rounds have no new Critical issues, suggest ending the loop.

## Key Principles
- **Never blindly accept Codex feedback** — it may misread code, cite wrong lines, or make assumptions. Every finding must be verified against actual source code before acting on it
- Only address actual issues identified in review — don't refactor surrounding code
- Custom prompt: `./scripts/code-review.sh --prompt "custom review instructions"`
