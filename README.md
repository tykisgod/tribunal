<p align="center">
  <img src="logo.png" alt="Tribunal" width="200">
</p>

<h1 align="center">Tribunal</h1>

<p align="center">
  Cross-model review for design docs and code.<br>
  Claude orchestrates, Codex reviews, every finding is verified against your actual source code.
</p>

[English](#english) | [中文](#中文) | [日本語](#日本語) | [한국어](#한국어)

---

# English

## The Problem

AI code reviewers hallucinate. They cite wrong line numbers, misread code, and make confident claims about bugs that don't exist. Single-model, single-pass review catches some real issues but also wastes your time on phantom ones.

## How Tribunal Works

```
You write a design doc or code
         |
   Codex reviews it
   [Critical] [Medium] [Suggestion]
         |
   Claude verifies each finding
   by reading your actual source code
   Confirmed / Rejected / Uncertain
         |
   Only confirmed issues get fixed
         |
   Still have [Critical]? --> loop (max 5 rounds)
         |
   Converged
```

The key step most tools skip: **verification**. Before acting on any review finding, Claude reads the exact files and lines cited to confirm the issue is real.

> **How it works under the hood:** Tribunal is not a standalone binary. The skill files (`.claude/commands/*.md`) are structured prompts that instruct Claude Code how to orchestrate the review loop — calling Codex via shell scripts, reading results, verifying claims against source code, and iterating. The shell scripts handle the Codex CLI invocation. Claude Code does the orchestration.

## Install

```bash
git clone https://github.com/tykisgod/tribunal.git
cd tribunal
./install.sh
```

Or manually copy:
- `commands/*.md` --> `.claude/commands/`
- `scripts/*.sh` --> `scripts/`

## Prerequisites

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) (requires Anthropic API key or Claude subscription)
- [Codex CLI](https://github.com/openai/codex) — `npm install -g @openai/codex` (requires OpenAI API key)

## Quick Start

### Example 1: Review a Design Doc Before Implementation

You've written an RFC for a new caching layer. Before writing any code, get it reviewed:

```
/tribunal-plan docs/caching-rfc.md
```

What happens:

```
=== Round 1/5 ===
Sending docs/caching-rfc.md to Codex for review...        # ~5 min

Codex found:
  [Critical] Section 3.2 claims Redis TTL defaults to 300s,
             but your config shows 60s (line 42 of config.yaml)
  [Medium]   Cache invalidation strategy doesn't handle
             concurrent writes
  [Suggestion] Consider adding metrics for cache hit rate

Verifying against source code...
  - Redis TTL claim: CONFIRMED — config.yaml:42 shows `ttl: 60`
  - Concurrent writes: CONFIRMED — no locking in write path
  - Metrics suggestion: noted

Fixing confirmed issues in the doc...
  - Updated TTL reference from 300s to 60s
  - Added concurrent write handling to Section 3.2

=== Round 2/5 ===
Sending updated doc to Codex...                            # ~5 min

Codex found:
  [Medium] The new locking strategy could deadlock if...
  [Suggestion] Typo in Section 4

No [Critical] issues. Review passed.
```

Total time: ~12 min. You caught a config mismatch and a concurrency bug before writing a single line of code.

### Example 2: Review Code Before a PR

You've finished a feature branch. Before opening a PR:

```
/tribunal-code
```

This diffs your branch against `develop`, sends the diff to Codex, and Claude verifies each finding against your actual code. Only real issues get flagged.

```
/tribunal-code --base main          # compare against main instead
/tribunal-code --commits            # only review the latest commit
/tribunal-code --ext "*.py"         # only review Python files
```

### Example 3: Review with Custom Focus

Your team just had a security incident. Review all recent changes with a security lens:

```
/tribunal-code --prompt "Focus exclusively on auth, input validation, and injection vectors"
```

Or for a design doc:

```
/tribunal-plan docs/api-spec.md "Focus on backward compatibility and breaking changes"
```

## Adapting to Your Project

### Step 1: Set Up CLAUDE.md (Recommended)

Tribunal automatically reads your project's `CLAUDE.md` for coding standards. This is the single most impactful customization — it tells the reviewer what your project cares about.

Example `CLAUDE.md`:

```markdown
## Coding Standards
- No raw SQL queries — use the ORM
- All public APIs must have OpenAPI annotations
- Error responses must follow RFC 7807 (Problem Details)
- No `any` types in TypeScript
```

With this in place, Codex will check your code against these rules automatically.

### Step 2: Add AGENTS.md for Architecture Context (Optional)

If your project has an `AGENTS.md` (architecture documentation), Tribunal reads it too. This helps the reviewer understand your dependency layers, module boundaries, and anti-patterns.

### Step 3: Customize the Review Prompt (Optional)

The default prompts cover general code quality. For domain-specific reviews, pass a custom prompt:

```bash
# Backend API project
./scripts/code-review.sh --prompt "Check for N+1 queries, missing indexes, and unhandled error codes"

# Game development
./scripts/plan-review.sh design.md "Focus on game feel, frame budget, and deterministic simulation"

# Data pipeline
./scripts/code-review.sh --prompt "Check for data loss, idempotency, and schema evolution"
```

### Step 4: Change the Base Branch (Optional)

Default is `develop`. If your project uses `main`:

Edit `scripts/code-review.sh` line 22:
```bash
BASE_BRANCH="main"
```

Or pass it each time: `--base main`

## How to Edit the Skills

The skills live in `.claude/commands/` after install. They're plain Markdown files that instruct Claude Code how to orchestrate the review loop. You can edit them freely:

| File | What to Customize |
|------|------------------|
| `tribunal-plan.md` | How plan reviews work — number of rounds, severity thresholds, convergence criteria |
| `tribunal-code.md` | How code reviews work — whether fixes are auto-applied or need approval |

Common modifications:

**Change max rounds** — find "max 5 rounds" and "5 rounds completed" in the skill file, change to your preferred limit.

**Auto-fix vs. ask first** — by default, `tribunal-code` asks before fixing. To make it auto-fix like `tribunal-plan`, edit the "Ask the user whether to proceed" line.

**Add project-specific review criteria** — you can hardcode domain checks directly in the skill file, e.g., "Also verify that all database migrations are reversible."

## What Makes This Different

| Feature | Tribunal | Typical AI Review |
|---------|----------|-------------------|
| Cross-model | Claude + Codex | Single model |
| Verification | Reads source to confirm each finding | Trusts its own output |
| Multi-round | Up to 5 rounds, auto-converges | Single pass |
| Severity gating | Loops until no [Critical] | No convergence logic |
| Design docs | Yes | Code only |

## Limitations

- **Speed** — each Codex review round takes ~5-10 minutes. A full 5-round loop can take 30+ minutes.
- **Cost** — runs both Claude (orchestrator) and Codex (reviewer), so you're paying two providers per review session.
- **Text only** — cannot review images, binary files, or UI rendering.
- **Large diffs** — works best under ~5000 lines of diff. Larger diffs won't fail, but review quality drops as Codex attention spreads thin.

## Troubleshooting

**`codex: command not found`** — install Codex CLI: `npm install -g @openai/codex`

**Codex returns empty output** — check your OpenAI API key is set: `echo $OPENAI_API_KEY`

**Review takes forever** — Codex is running a large prompt. Wait for the background task notification. If it exceeds 10 minutes, check your network.

**Claude doesn't follow the review loop** — make sure the skill files are in `.claude/commands/` (not a subdirectory). Run `ls .claude/commands/tribunal-*.md` to verify.

## Tips

- **Review the spec first, then the code.** Catching an architecture mistake in a doc costs 30 seconds to fix. Catching it in code costs hours.
- **Write a good CLAUDE.md.** The better your coding standards doc, the more project-relevant the review findings will be.
- **Don't skip the verification step.** That's the whole point. If you just want raw AI review without verification, you don't need Tribunal.
- **Custom prompts for focused reviews.** A generic "review this" catches less than "check for race conditions in the message queue" does.

## Why "Tribunal"

One judge isn't enough. Two models checking each other's work catches more real issues and fewer false positives than either alone.

---

# 中文

## 问题

AI 代码审阅会产生幻觉——引用错误的行号、误读代码、对不存在的 bug 做出自信的断言。单模型、单轮审阅能抓到一些真问题，但也会让你在虚假问题上浪费时间。

## 工作原理

```
你写了设计文档或代码
         |
   Codex 审阅
   [Critical] [Medium] [Suggestion]
         |
   Claude 逐条验证每个发现
   通过阅读你的实际源码
   确认 / 否决 / 不确定
         |
   只修复被确认的问题
         |
   还有 [Critical]？ --> 循环（最多 5 轮）
         |
   收敛
```

大多数工具跳过的关键步骤：**验证**。在处理任何审阅发现之前，Claude 会读取被引用的实际文件和行号，确认问题是否真实存在。

> **底层机制：** Tribunal 不是独立程序。Skill 文件（`.claude/commands/*.md`）是结构化的 prompt，指导 Claude Code 如何编排审阅循环——调用 Codex、读取结果、验证断言、迭代修复。Shell 脚本负责调用 Codex CLI，Claude Code 负责编排。

## 安装

```bash
git clone https://github.com/tykisgod/tribunal.git
cd tribunal
./install.sh
```

或手动复制：
- `commands/*.md` --> `.claude/commands/`
- `scripts/*.sh` --> `scripts/`

## 前置条件

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code)（需要 Anthropic API key 或 Claude 订阅）
- [Codex CLI](https://github.com/openai/codex) — `npm install -g @openai/codex`（需要 OpenAI API key）

## 快速开始

### 示例 1：实现前审阅设计文档

```
/tribunal-plan docs/caching-rfc.md
```

Codex 审阅文档，Claude 逐条验证。发现配置值写错了？30 秒改一段话。比写完代码再发现省几个小时。

### 示例 2：提 PR 前审阅代码

```
/tribunal-code                      # 对比 develop...HEAD
/tribunal-code --base main          # 对比 main
/tribunal-code --commits            # 只看最新 commit
/tribunal-code --ext "*.py"         # 只看 Python 文件
```

### 示例 3：带自定义关注点的审阅

```
/tribunal-code --prompt "重点检查认证、输入校验和注入漏洞"
/tribunal-plan docs/api-spec.md "关注向后兼容性和破坏性变更"
```

## 适配你的项目

**CLAUDE.md**（推荐）— 写上你的编码标准，Codex 会自动据此审阅：

```markdown
## 编码标准
- 不写裸 SQL，用 ORM
- 所有公开 API 必须有 OpenAPI 注解
- TypeScript 禁止 any 类型
```

**AGENTS.md**（可选）— 写上架构层级和模块边界，帮助审阅者理解依赖方向。

**修改 Skill 文件** — 安装后在 `.claude/commands/tribunal-*.md`，纯 Markdown，可以自由编辑：改循环轮数、改收敛条件、加项目特定检查项。

**改基准分支** — 默认 `develop`，用 `--base main` 或直接改脚本。

## 局限性

- **速度** — 每轮 Codex 审阅需要 ~5-10 分钟，完整 5 轮可能超过 30 分钟。
- **成本** — 同时消耗 Claude 和 Codex 两个服务的 API 额度。
- **仅文本** — 无法审阅图片、二进制文件或 UI 渲染效果。
- **大 diff** — 建议 ~5000 行以内。更大的 diff 不会失败，但审阅质量会下降。

## 常见问题

**`codex: command not found`** — 安装 Codex CLI：`npm install -g @openai/codex`

**Codex 返回空输出** — 检查 OpenAI API key：`echo $OPENAI_API_KEY`

**Claude 没有执行审阅循环** — 确认 skill 文件在 `.claude/commands/` 下：`ls .claude/commands/tribunal-*.md`

## 使用建议

- **先审 spec，再写代码。** 文档里发现架构问题改一句话，代码里发现要改半天。
- **写好 CLAUDE.md。** 编码标准越清晰，审阅发现越贴合项目。
- **不要跳过验证步骤。** 这是 Tribunal 的核心价值。
- **用自定义 prompt 做定向审阅。** "检查消息队列的竞态条件"比泛泛的"审阅一下"有效得多。

---

# 日本語

## 問題

AIコードレビューは幻覚を起こします。間違った行番号を引用し、コードを誤読し、存在しないバグについて自信を持って主張します。単一モデル・単一パスのレビューは一部の本物の問題を見つけますが、架空の問題にも時間を浪費させます。

## 仕組み

```
設計ドキュメントまたはコードを書く
         |
   Codex がレビュー
   [Critical] [Medium] [Suggestion]
         |
   Claude が各指摘を独立検証
   実際のソースコードを読んで確認
   確認済み / 否定 / 不明
         |
   確認された問題のみ修正
         |
   まだ [Critical] がある？ --> ループ（最大5ラウンド）
         |
   収束
```

> **仕組みの詳細：** Tribunalは独立したバイナリではありません。Skillファイル（`.claude/commands/*.md`）がClaude Codeにレビューループの進め方を指示する構造化プロンプトです。シェルスクリプトがCodex CLIを呼び出し、Claude Codeがオーケストレーションを担当します。

## インストール

```bash
git clone https://github.com/tykisgod/tribunal.git
cd tribunal
./install.sh
```

または手動コピー：
- `commands/*.md` --> `.claude/commands/`
- `scripts/*.sh` --> `scripts/`

## 前提条件

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code)（Anthropic APIキーまたはClaudeサブスクリプションが必要）
- [Codex CLI](https://github.com/openai/codex) — `npm install -g @openai/codex`（OpenAI APIキーが必要）

## クイックスタート

### 例1：実装前に設計ドキュメントをレビュー

```
/tribunal-plan docs/caching-rfc.md
```

Codexがドキュメントをレビューし、Claudeが各指摘を検証。設定値の間違いを発見？ドキュメントの修正は30秒。コードを書いた後に気づくより数時間節約。

### 例2：PR前にコードをレビュー

```
/tribunal-code                      # develop...HEAD と比較
/tribunal-code --base main          # main と比較
/tribunal-code --commits            # 最新コミットのみ
/tribunal-code --ext "*.py"         # Pythonファイルのみ
```

### 例3：カスタムフォーカスでレビュー

```
/tribunal-code --prompt "認証、入力検証、インジェクション脆弱性に焦点を当てる"
/tribunal-plan docs/api-spec.md "後方互換性と破壊的変更に注目"
```

## プロジェクトへの適応

**CLAUDE.md**（推奨）— コーディング規約を記述。Codexが自動的にこれに基づいてレビュー。

**AGENTS.md**（オプション）— アーキテクチャの階層とモジュール境界を記述。

**Skillファイルの編集** — インストール後 `.claude/commands/tribunal-*.md` にあります。プレーンMarkdownなので自由に編集可能。

**ベースブランチの変更** — デフォルトは `develop`。`--base main` またはスクリプトを直接編集。

## 制限事項

- **速度** — Codexレビュー1ラウンドに~5-10分。フル5ラウンドで30分以上。
- **コスト** — ClaudeとCodex両方のAPI料金が発生。
- **テキストのみ** — 画像、バイナリファイル、UIレンダリングはレビュー不可。
- **大きなdiff** — ~5000行以内推奨。それ以上でも動作するが、レビュー品質が低下。

## ヒント

- **まずSpecをレビュー、次にコード。** ドキュメントでアーキテクチャの問題を見つければ一文で修正。コードで見つけると半日かかる。
- **CLAUDE.mdをしっかり書く。** コーディング規約が明確なほど、レビューの指摘がプロジェクトに合致する。
- **検証ステップを飛ばさない。** これがTribunalの核心的価値。
- **カスタムプロンプトで的を絞ったレビューを。**

---

# 한국어

## 문제

AI 코드 리뷰는 환각을 일으킵니다. 잘못된 줄 번호를 인용하고, 코드를 잘못 읽고, 존재하지 않는 버그에 대해 확신에 찬 주장을 합니다. 단일 모델, 단일 패스 리뷰는 일부 실제 문제를 찾지만, 허구의 문제에도 시간을 낭비하게 합니다.

## 작동 방식

```
설계 문서 또는 코드를 작성
         |
   Codex가 리뷰
   [Critical] [Medium] [Suggestion]
         |
   Claude가 각 발견사항을 독립 검증
   실제 소스 코드를 읽어서 확인
   확인됨 / 기각 / 불확실
         |
   확인된 문제만 수정
         |
   아직 [Critical]이 있나? --> 루프 (최대 5라운드)
         |
   수렴
```

> **내부 작동:** Tribunal은 독립 실행 프로그램이 아닙니다. Skill 파일(`.claude/commands/*.md`)이 Claude Code에 리뷰 루프를 어떻게 진행할지 지시하는 구조화된 프롬프트입니다. 셸 스크립트가 Codex CLI를 호출하고, Claude Code가 오케스트레이션을 담당합니다.

## 설치

```bash
git clone https://github.com/tykisgod/tribunal.git
cd tribunal
./install.sh
```

또는 수동 복사:
- `commands/*.md` --> `.claude/commands/`
- `scripts/*.sh` --> `scripts/`

## 사전 요구사항

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) (Anthropic API 키 또는 Claude 구독 필요)
- [Codex CLI](https://github.com/openai/codex) — `npm install -g @openai/codex` (OpenAI API 키 필요)

## 빠른 시작

### 예시 1: 구현 전 설계 문서 리뷰

```
/tribunal-plan docs/caching-rfc.md
```

Codex가 문서를 리뷰하고, Claude가 각 지적을 검증합니다. 설정값 오류 발견? 문서 수정은 30초. 코드 작성 후 발견하면 몇 시간이 걸립니다.

### 예시 2: PR 전 코드 리뷰

```
/tribunal-code                      # develop...HEAD 비교
/tribunal-code --base main          # main과 비교
/tribunal-code --commits            # 최신 커밋만
/tribunal-code --ext "*.py"         # Python 파일만
```

### 예시 3: 커스텀 포커스 리뷰

```
/tribunal-code --prompt "인증, 입력 검증, 인젝션 취약점에 집중"
/tribunal-plan docs/api-spec.md "하위 호환성과 파괴적 변경에 주목"
```

## 프로젝트 맞춤 설정

**CLAUDE.md** (권장) — 코딩 표준을 작성하면 Codex가 자동으로 이에 기반하여 리뷰합니다.

**AGENTS.md** (선택) — 아키텍처 계층과 모듈 경계를 작성합니다.

**Skill 파일 편집** — 설치 후 `.claude/commands/tribunal-*.md`에 있습니다. 순수 Markdown이므로 자유롭게 편집 가능.

**기준 브랜치 변경** — 기본값은 `develop`. `--base main` 또는 스크립트를 직접 편집.

## 제한 사항

- **속도** — Codex 리뷰 1라운드에 ~5-10분. 전체 5라운드면 30분 이상.
- **비용** — Claude와 Codex 두 서비스의 API 요금이 발생.
- **텍스트만** — 이미지, 바이너리 파일, UI 렌더링은 리뷰 불가.
- **큰 diff** — ~5000줄 이내 권장. 그 이상도 동작하지만 리뷰 품질이 저하.

## 팁

- **먼저 Spec을 리뷰하고, 그 다음 코드를.** 문서에서 아키텍처 문제를 발견하면 한 문장 수정. 코드에서 발견하면 반나절.
- **CLAUDE.md를 잘 작성하세요.** 코딩 표준이 명확할수록 리뷰 결과가 프로젝트에 적합해집니다.
- **검증 단계를 건너뛰지 마세요.** 이것이 Tribunal의 핵심 가치입니다.
- **커스텀 프롬프트로 집중 리뷰를.**
