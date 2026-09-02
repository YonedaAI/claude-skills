---
name: research-agent
description: "Use when the user asks to research topics, generate research papers, run a research pipeline, create academic papers with peer review, or invokes /research-agent. Orchestrates parallel research agents with Gemini peer review, Codex formatting checks, optional Haskell verification, Vercel website deployment, multi-platform social posts, and Slack notifications."
version: 0.7.12
---

# Research Agent Pipeline — Orchestration

This skill orchestrates an 8-phase multi-agent research pipeline. Each phase spawns specialized agents that draft, review, verify, publish, and promote research papers.

## Input Contract

The command passes these parsed values:
- `$TOPICS` — array of research topic slugs (e.g. `["quantum-gravity", "entanglement"]`)
- `$PERSPECTIVE` — framing perspective for all papers
- `$PROJECT` — project directory name
- `$PROJECT_PATH` — absolute path to create project (default: cwd)
- `$GITHUB_ORG` — GitHub organization (from `$RESEARCH_GITHUB_ORG` env var or default `YonedaAI`)
- `$SLACK_CHANNEL` — Slack channel ID (from `$RESEARCH_SLACK_CHANNEL` env var or default `C0AK269AVSA`)
- `$SKIP_HASKELL`, `$SKIP_WEBSITE`, `$SKIP_SOCIAL` — boolean flags. When `$SKIP_HASKELL` is true, the Phase 3 worker prompt MUST also carry the line `Haskell is OFF: write no src/ directory` (see Phase 3) — the flag alone does not stop workers from writing Haskell.
- `$MULTI_AGENT_TEAM` — boolean (`--multi-agent-team`). Workers exchange interface contracts in `team/<slug>/contract.md`, log to `team/board.md`, reconcile cross-references with sibling drafts, and an integration reviewer gate runs before Phase 4. Protocol: `references/team-protocol.md`. Applied in Phase 3.
- `$HUMAN_READABLE` — boolean (`--human-readable`). Workers apply the humanizer rules and the orchestrator runs the grep checks from `references/team-protocol.md` before the final compile. Applied in Phase 3 (worker prompt) and Phase 4.5 (checks).
- `$CODE_AUDIT` — boolean (`--code-audit`). After the Codex formatting loop, a Codex read-only audit of the paper's code evidence appendix must return SUPPORTS on every row. Applied in Phase 3 (worker Stage 4b).
- `$BIB_GATE` — boolean (`--bib-gate`). Every bibliography entry with an arXiv id, DOI or URL is resolved with WebFetch before the final compile; unresolved entries are removed or replaced. Applied in Phase 4.5.
- `$PLAN_CRITIQUE` — boolean (`--plan-critique`). Before Phase 2 the orchestrator writes the plan to `PLAN.md` and runs a Codex read-only critique until VERDICT: PROCEED (max 3 rounds). Applied in Phase 1 (Step 1d).
- `$CODEX_MODEL`, `$CODEX_EFFORT` — from `--codex-model <m>` / `--codex-effort <e>`; exported as `RESEARCH_CODEX_MODEL` / `RESEARCH_CODEX_EFFORT` (defaults `gpt-5.6-sol` / `high`) so every sub-agent inherits them.

## Environment Variables

Read these at the start of execution. All have sensible defaults — none are required.

| Env Var | Default | Purpose |
|---------|---------|---------|
| `RESEARCH_AUTHOR_NAME` | `Matthew Long` | Paper author name |
| `RESEARCH_AUTHOR_EMAIL` | `matthew@yonedaai.com` | Author contact email |
| `RESEARCH_AUTHOR_URL` | `https://yonedaai.com` | Author website |
| `RESEARCH_COLLABORATION` | `The YonedaAI Collaboration` | Collaboration line in author block |
| `RESEARCH_INSTITUTION` | `YonedaAI Research Collective` | Institution line in author block |
| `RESEARCH_LOCATION` | `Chicago, IL` | Author location |
| `RESEARCH_GITHUB_ORG` | `YonedaAI` | GitHub organization for repo creation |
| `RESEARCH_SLACK_CHANNEL` | `C0AK269AVSA` | Slack channel ID for notifications |
| `RESEARCH_GEMINI_MODEL` | `gemini-3.1-pro` | Gemini model for peer review |
| `RESEARCH_WORKER_MODEL` | `opus` | Model for research-worker and synthesis agents |
| `RESEARCH_UTILITY_MODEL` | `sonnet` | Model for utility agents (KB builder, website, social) |
| `RESEARCH_GEMINI_BIN` | `/Users/mlong/.local/bin/agy-review-shim` | Peer-review CLI: the `agy` (Antigravity) shim `agy-review-shim` (routes review calls to agy, model "Gemini 3.1 Pro (High)"). Required because Node is managed via `fnm` and shims are not active in non-interactive Bash subshells spawned by agents. The shim passes `--effort` only when `AGY_REVIEW_EFFORT` is set (agy >= 1.1.23 rejects `--effort` for models whose name already carries effort) and logs stderr to `${TMPDIR:-/tmp}/agy-review-shim.err`. |
| `AGY_REVIEW_EFFORT` | *(unset)* | Only set this when `AGY_REVIEW_MODEL` names a model WITHOUT an effort suffix. Leave unset for "Gemini 3.1 Pro (High)" — agy 1.1.23+ exits with a flag error otherwise and the review comes back empty. |
| `RESEARCH_CODEX_BIN` | `/Users/mlong/.local/share/fnm/node-versions/v24.14.0/installation/bin/codex` | Absolute path to the `codex` CLI. Same fnm reasoning — agents and the `codex:rescue` skill can't find `codex` on a raw `$PATH`. |
| `RESEARCH_CODEX_MODEL` | `gpt-5.6-sol` | Model passed as `-m` to every direct `codex exec` call (workers, synthesis, Haskell verifier, code audit, plan critique). Set by `--codex-model`. |
| `RESEARCH_CODEX_EFFORT` | `high` | Value for `-c model_reasoning_effort=...` on every direct `codex exec` call. Set by `--codex-effort`. The Phase 1 sanity test uses `low` regardless. |
| `RESEARCH_GIT_AUTHOR` | `Matthew <mlong@magneton.io>` | Git author for every commit the pipeline makes (RFC 2822 `Name <email>` form). Parsed into `RESEARCH_GIT_AUTHOR_NAME` and `RESEARCH_GIT_AUTHOR_EMAIL` by the resolver below. |
| `RESEARCH_GIT_AUTHOR_NAME` | `Matthew` | Override the parsed name. Takes precedence over `RESEARCH_GIT_AUTHOR` if set. |
| `RESEARCH_GIT_AUTHOR_EMAIL` | `mlong@magneton.io` | Override the parsed email. Takes precedence over `RESEARCH_GIT_AUTHOR` if set. |

### Tool Resolution — fnm / PATH setup

Node is managed via `fnm`, so `gemini` and `codex` are not on the default `PATH` inside non-interactive Bash subshells. Every agent that shells out to these tools MUST resolve them to absolute paths at the start of its run. Paste this block verbatim at the top of any Bash sequence that calls `gemini` or `codex`:

```bash
# Resolve the reviewer shim + codex to absolute paths (fnm shims aren't active in agent subshells)
GEMINI="${RESEARCH_GEMINI_BIN:-/Users/mlong/.local/bin/agy-review-shim}"
CODEX="${RESEARCH_CODEX_BIN:-/Users/mlong/.local/share/fnm/node-versions/v24.14.0/installation/bin/codex}"
# NO fallback to the plain `gemini` CLI — it is deprecated and exits immediately (see below).
[ -x "$GEMINI" ] || { echo "FATAL: reviewer shim not executable at $GEMINI — see ${TMPDIR:-/tmp}/agy-review-shim.err"; exit 1; }
[ -x "$CODEX" ]  || CODEX="$(command -v codex  2>/dev/null || echo codex)"
# Also prepend the fnm bin dir so nested tools (node, npx) resolve correctly
export PATH="$(dirname "$CODEX"):$(dirname "$GEMINI"):$PATH"
export RESEARCH_CODEX_MODEL="${RESEARCH_CODEX_MODEL:-gpt-5.6-sol}"
export RESEARCH_CODEX_EFFORT="${RESEARCH_CODEX_EFFORT:-high}"
```

From that point in the script, always invoke `"$GEMINI"` and `"$CODEX"` — never bare `gemini` / `codex`, which will fail with `command not found` in agent subshells.

**Reviewer shim facts (read before debugging an empty review):**

- `agy` 1.1.23 and later **reject `--effort`** for models whose name already carries an effort level (e.g. "Gemini 3.1 Pro (High)"). The shim at `/Users/mlong/.local/bin/agy-review-shim` therefore passes `--effort` **only when `AGY_REVIEW_EFFORT` is set**. Do not export `AGY_REVIEW_EFFORT` for the default model.
- The shim logs agy's stderr to **`${TMPDIR:-/tmp}/agy-review-shim.err`**. When a review comes back empty, header-only, or the shim exits non-zero, **read that log first** — flag errors, auth errors, and timeouts all land there.
- The plain **`gemini` CLI is no longer usable**: Google deprecated Gemini Code Assist for individuals and it exits with "This client is no longer supported ... migrate to Antigravity". **Do not fall back to it** and do not resolve `$GEMINI` to it. If the shim is missing, the pipeline stops.
- Known-good direct invocation of the underlying reviewer (for manual debugging only): `agy -p "<prompt with full paper source inlined>" --model "Gemini 3.1 Pro (High)"` — no `--effort`; passing a file path does not work (print mode does not read files); use `--new-project` when retrying to avoid a stale session.

**Reviewer calls must be serialized.** Concurrent `agy` or `codex` invocations from parallel workers return empty output. Every call to `"$GEMINI"` or `"$CODEX"` — in any agent — must hold the project-wide mutex directory `$PROJECT_ROOT/.review.lock` (mkdir-based). Wrap each **single** reviewer call like this, never the agent's own fix work:

```bash
LOCK="$PROJECT_ROOT/.review.lock"
until mkdir "$LOCK" 2>/dev/null; do sleep 30; done; trap 'rmdir "$LOCK" 2>/dev/null' EXIT
... one reviewer call ...
rmdir "$LOCK" 2>/dev/null; trap - EXIT
```

`.review.lock/` is git-ignored (Phase 1). If a run is aborted mid-review, remove a stale lock with `rmdir "$PROJECT_ROOT/.review.lock"` before restarting.

**Direct `codex exec` is the only way sub-agents can run Codex.** Sub-agents (research-worker, synthesis-agent, haskell-verifier) have no `Skill` tool, so they cannot invoke `codex:rescue`. They run this command instead (the orchestrator may use either `codex:rescue` or this command; the direct command is preferred whenever a specific model or effort is requested):

```bash
timeout 1200 "$CODEX" exec -m "${RESEARCH_CODEX_MODEL:-gpt-5.6-sol}" -c "model_reasoning_effort=\"${RESEARCH_CODEX_EFFORT:-high}\"" -s read-only --skip-git-repo-check "<concise prompt; tell Codex which single file to read and not to explore other files; end with VERDICT: PASS or VERDICT: NEEDS_FIX>" </dev/null >> "$ROUND_FILE" 2>&1
```

Gotchas: `</dev/null` is mandatory (otherwise Codex hangs on "Reading additional input from stdin"); `-s read-only` prevents Codex from editing files (the agent applies fixes itself); `--skip-git-repo-check` is needed outside a git repo; prompts must be concise and name the single file to read, or Codex explores the whole repository and the review file balloons.

### Slack Message Linter (`slack_lint_msg`)

Before EVERY `mcp__claude_ai_Slack__slack_send_message` call, run the proposed message text through this linter. The MCP tool takes **standard markdown**: links MUST be `[label](https://...)`, bold is `**text**`. The angle-bracket form `<https://...>` is WRONG for this tool — it renders literally. A bare URL is also rejected (Slack's auto-linker bleeds adjacent markers into the link). Paste this function near the top of any Bash block that composes a Slack message:

```bash
# Slack message linter — call before every slack_send_message tool invocation.
# Usage:
#   slack_lint_msg "$MSG" || { echo "fix the message before sending"; exit 1; }
slack_lint_msg() {
  local msg="$1" fail=0 bare angle bleed unb
  bare=$(printf '%s\n' "$msg" | grep -nE '(^|[^(<])https?://' || true)
  [ -n "$bare" ] && { echo "slack_lint: FAIL bare URL(s), use [label](url):"; printf '%s\n' "$bare" | sed 's/^/  /'; fail=1; }
  angle=$(printf '%s\n' "$msg" | grep -nE '<https?://' || true)
  [ -n "$angle" ] && { echo "slack_lint: FAIL angle-bracket URL(s), use [label](url):"; printf '%s\n' "$angle" | sed 's/^/  /'; fail=1; }
  bleed=$(printf '%s\n' "$msg" | grep -nE '\)[[:space:]]*\*' || true)
  [ -n "$bleed" ] && { echo "slack_lint: FAIL link immediately followed by a bold marker:"; printf '%s\n' "$bleed" | sed 's/^/  /'; fail=1; }
  unb=$(printf '%s\n' "$msg" | awk '{ n=gsub(/\*\*/,"&"); if (n % 2) print NR": "$0 }' || true)
  [ -n "$unb" ] && { echo "slack_lint: FAIL unbalanced ** on line(s):"; printf '%s\n' "$unb" | sed 's/^/  /'; fail=1; }
  return $fail
}
```

This is a HARD GATE. If `slack_lint_msg` returns non-zero, fix the message text — do NOT send it. Put every URL on its own bold-label line, e.g. `**Website:** [agent-engineering.vercel.app](https://agent-engineering.vercel.app)` and `**GitHub:** [YonedaAI/agent-engineering](https://github.com/YonedaAI/agent-engineering)`.

## CRITICAL — Mandatory Steps (never skip these)

Every phase has a MANDATORY checkpoint. You MUST complete ALL of these — they are not optional:

1. **Gemini peer review loop** — Every paper (workers + synthesis) MUST be reviewed by `"$GEMINI" -m $RESEARCH_GEMINI_MODEL` (the agy shim) in an iterative loop: review → fix → re-review → fix → ... until the reviewer's VERDICT is ACCEPT or MINOR REVISIONS. Max 4 rounds per paper. Reviews saved to `reviews/$TOPIC-review-round-N.md`. Every reviewer call holds the `$PROJECT_ROOT/.review.lock` mutex (Tool Resolution section). The Phase 1 reviewer sanity tests MUST pass before any worker spawns. Skipping this is a pipeline failure.
2. **Codex formatting check** — Every paper MUST be checked by Codex after the review loop. Sub-agents run the direct `"$CODEX" exec ... -s read-only` command (Tool Resolution section); the orchestrator may use `codex:rescue` or the direct command. Skipping this is a pipeline failure.
3. **Codex website review** — The website MUST be reviewed by `codex:rescue` (or the equivalent direct command) BEFORE Vercel deployment (Step 6d). Skipping this is a pipeline failure.
4. **Slack per-topic notifications** — Send a Slack message after EACH worker completes, after synthesis completes, after Haskell verification completes, after website deployment, and a final summary. These are 5+ separate Slack messages minimum.
5. **Review-fix loops** — Both reviewers iterate. **Gemini**: review → fix → re-review until VERDICT is ACCEPT or MINOR REVISIONS, or 4 rounds exhausted. **Codex**: review → fix → re-review until VERDICT is PASS, or 2 fix passes exhausted (3 total invocations). Each round writes its own `reviews/<topic>-review-round-N.md` (Gemini) or `reviews/<topic>-codex-review-round-N.md` (Codex). The final canonical review file is a copy of the last round. After Phase 3/4/5, the orchestrator runs a hard gate that respawns the worker if any review is missing/stub-only/non-iterating, and aborts the pipeline if the respawn still fails. Soft-fallback paths (`SKIPPED:` stub files, "run the loop yourself") have been removed.
6. **Bypass permissions on every Agent spawn** — This pipeline runs unattended. Every `Agent` tool call MUST set `mode: "bypassPermissions"` so sub-agents never pause for permission prompts on Bash/Write/Edit/WebFetch. A single prompt stalls the whole run. See "Agent Spawning Rules" below.
7. **Every URL in every Slack message MUST be a markdown link `[label](https://...)`** — `mcp__claude_ai_Slack__slack_send_message` takes standard markdown. The angle-bracket form `<https://...>` is WRONG for this tool and renders literally. A bare URL is also wrong: Slack's auto-linker is greedy and pulls adjacent `*bold*` markers or punctuation into the link (observed: `https://github.com/org/repo *Social` rendered as a link to `…/repo *Social`, simultaneously breaking bold formatting). Put each link on its own bold-label line, e.g. `**Website:** [agent-engineering.vercel.app](https://agent-engineering.vercel.app)`. NEVER paste a raw or angle-bracketed URL into a Slack message. Applies to every `mcp__claude_ai_Slack__slack_send_message` call — worker completion, synthesis, Haskell, website deploy, final summary, and any error notifications.
8. **Run `slack_lint_msg` before EVERY Slack send and `pipeline-validator` before the final Phase 8 Slack send.** The inline `slack_lint_msg` Bash function (defined above in "Slack Message Linter") gates every individual message — a single bare URL, angle-bracket URL, or unbalanced `**` marker blocks the send. The `pipeline-validator` agent (definition: `agents/pipeline-validator.md`) gates the final summary by additionally validating OG image dimensions/std-dev, `.vercel-url` integrity, and required artifact presence. Both gates are MANDATORY — a FAIL means fix the issue and re-validate, never bypass.

If you present a plan to the user, the plan MUST explicitly list all 8 of the above as separate line items. Do not collapse them into a phase header.

---

## Publication Presentation Contract — HARD GATE

The final papers, synthesis, website, README, and public release copy must read as finished scholarly works, not as records of the agent pipeline.

- Do not impose a blanket claim taxonomy or add confidence badges, provenance labels, reviewer verdicts, audit status, agent activity, or internal workflow metadata to public artifacts.
- Use ordinary scholarly and mathematical conventions—Definition, Lemma, Proposition, Theorem, Proof, Remark, or Conjecture—only where they naturally serve the argument.
- Resolve unsupported claims by proving them, citing an external result, narrowing their scope, revising them, or removing them. Do not preserve weak material by attaching an internal status label.
- Review files and private receipts may retain operational evidence, but that evidence must not leak into paper prose, headings, tables, sidebars, badges, or website copy.
- Every paper, synthesis, formatting review, and website review must explicitly check for and remove process-language leakage before acceptance.

This presentation rule does not weaken mathematical rigor. Premises, hypotheses, proofs, citations, limitations, and open problems still belong in the work through normal scholarly exposition.

---

## Author Block (used in all papers)

Constructed from env vars at runtime:

```
$RESEARCH_AUTHOR_NAME
$RESEARCH_COLLABORATION
$RESEARCH_INSTITUTION
$RESEARCH_LOCATION
$RESEARCH_AUTHOR_EMAIL · $RESEARCH_AUTHOR_URL
```

---

## Phase 1 — Project Setup

Create the project directory and initialize git. **Also resolve the git author variable and pin it on the new repo** so every commit this pipeline makes uses `$RESEARCH_GIT_AUTHOR` (default `Matthew <mlong@magneton.io>`), not whatever global `user.name`/`user.email` happens to be configured on the machine.

```bash
mkdir -p $PROJECT_PATH/$PROJECT/{papers/{latex,pdf},src,reviews,posts/{twitter,linkedin,facebook,bluesky},images,docs/papers,website}
cd $PROJECT_PATH/$PROJECT && git init

# --- Git author resolution (applies to every `git commit` in this pipeline) ---
RESEARCH_GIT_AUTHOR="${RESEARCH_GIT_AUTHOR:-Matthew <mlong@magneton.io>}"
# Parse "Name <email>" into separate fields unless overrides are set
GIT_AUTHOR_NAME="${RESEARCH_GIT_AUTHOR_NAME:-$(echo "$RESEARCH_GIT_AUTHOR" | sed -E 's/ *<[^>]+> *$//')}"
GIT_AUTHOR_EMAIL="${RESEARCH_GIT_AUTHOR_EMAIL:-$(echo "$RESEARCH_GIT_AUTHOR" | sed -nE 's/.*<([^>]+)>.*/\1/p')}"
# Pin on the newly created repo (local config — does NOT touch the user's global config)
git config user.name  "$GIT_AUTHOR_NAME"
git config user.email "$GIT_AUTHOR_EMAIL"
# Also export for git's env-var path (belt + suspenders for `git commit`)
export GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL
export GIT_COMMITTER_NAME="$GIT_AUTHOR_NAME"
export GIT_COMMITTER_EMAIL="$GIT_AUTHOR_EMAIL"
# Verify
git config user.name
git config user.email
```

Every subsequent `git commit` in the pipeline (Phase 8b, follow-up commits, README commits, etc.) MUST be authored by `$RESEARCH_GIT_AUTHOR`. Do not override per-commit. If you need to double-pin a specific commit, pass `--author="$RESEARCH_GIT_AUTHOR"` to `git commit`.

Copy reusable conversion tools if available in the working directory:
```bash
# Copy from yoneda-ai or similar project if present
cp scripts/latex2html.py $PROJECT_PATH/$PROJECT/scripts/ 2>/dev/null || true
cp scripts/paper-template.html $PROJECT_PATH/$PROJECT/scripts/ 2>/dev/null || true
```

### Step 1a — .gitignore and sources licensing (MANDATORY)

Write the project `.gitignore` now, before any worker runs. Source PDFs that are arXiv preprints MUST NOT be committed (licensing); the review mutex directory must never be tracked either.

```bash
cd $PROJECT_PATH/$PROJECT
cat > .gitignore <<'EOF'
.DS_Store
# LaTeX aux files
*.aux
*.log
*.toc
*.out
*.bbl
*.blg
*.nav
*.snm
*.vrb
*.fls
*.fdb_latexmk
*.synctex.gz
# Website build output
website/node_modules/
website/.next/
website/out/
website/.vercel/
# Reviewer mutex (mkdir-based lock, see Tool Resolution)
.review.lock/
# Source preprints are not redistributable — link them from sources/README.md instead
sources/*.pdf
sources/*.txt
EOF
```

If a `sources/` directory exists (or is created later), it MUST contain a `sources/README.md` that lists every source with a link to its arXiv abstract page (`https://arxiv.org/abs/<id>`) or publisher page instead of the file itself. The knowledge-base-builder reads the local PDFs; the repository ships only the README. Phase 8b verifies this.

### Step 1b — Reviewer sanity tests (MANDATORY — before any worker spawns)

Both external reviewers must prove they work end-to-end BEFORE Phase 2/3. A broken shim otherwise surfaces only as empty review files hours later. Run the Tool Resolution block first, then these two tests (each finishes in about 60 seconds):

```bash
cd $PROJECT_PATH/$PROJECT
printf 'Theorem 1. The identity is a coalgebra homomorphism. Proof. Immediate.\n' | "$GEMINI" -m gemini-3.1-pro -p "Peer review this note in at least 600 characters. End with a line VERDICT: ACCEPT or VERDICT: MINOR REVISIONS." | grep -q VERDICT && echo "REVIEWER OK" || { echo "FATAL: reviewer shim broken, see ${TMPDIR:-/tmp}/agy-review-shim.err"; exit 1; }

"$CODEX" exec -m "${RESEARCH_CODEX_MODEL:-gpt-5.6-sol}" -c 'model_reasoning_effort="low"' -s read-only --skip-git-repo-check "Reply with exactly: CODEX OK" </dev/null | grep -q "CODEX OK" && echo "CODEX OK" || { echo "FATAL: codex broken"; exit 1; }
```

Do not proceed on FATAL. Read `${TMPDIR:-/tmp}/agy-review-shim.err` for the reviewer; for Codex check `"$CODEX" login status` and the model name.

### Step 1c — Export Codex settings for sub-agents

```bash
export RESEARCH_CODEX_MODEL="${CODEX_MODEL:-${RESEARCH_CODEX_MODEL:-gpt-5.6-sol}}"
export RESEARCH_CODEX_EFFORT="${CODEX_EFFORT:-${RESEARCH_CODEX_EFFORT:-high}}"
```

Pass both values explicitly in every agent prompt as well (`RESEARCH_CODEX_MODEL=... RESEARCH_CODEX_EFFORT=...`) — sub-agent shells do not always inherit the orchestrator's exports.

### Step 1d — Plan critique (only when `--plan-critique`)

Before Phase 2, write the full pipeline plan (topics, perspective, per-topic scope, flags in effect, phase list with the 8 CRITICAL items) to `$PROJECT_PATH/$PROJECT/PLAN.md`, then ask Codex to critique it:

```bash
cd $PROJECT_PATH/$PROJECT
ROUND=1
timeout 600 "$CODEX" exec -m "${RESEARCH_CODEX_MODEL:-gpt-5.6-sol}" -c "model_reasoning_effort=\"${RESEARCH_CODEX_EFFORT:-high}\"" -s read-only --skip-git-repo-check "Critique this research pipeline plan. Do not read any files. List blocking problems (scope too large, topics overlapping, missing dependencies, unverifiable claims) and non-blocking suggestions. End with exactly one line: VERDICT: PROCEED or VERDICT: REVISE.
$(cat PLAN.md)" </dev/null > "reviews/plan-critique-round-$ROUND.md" 2>&1
tail -5 "reviews/plan-critique-round-$ROUND.md" | grep -i VERDICT
```

On `VERDICT: REVISE`, revise `PLAN.md` to address the blocking items and re-run with `ROUND=2`, then `ROUND=3`. Stop when the verdict is PROCEED, when only non-blocking items remain, or after three rounds. Copy the last round to `reviews/plan-critique.md`. The critique never runs Codex in write mode and never edits the plan itself.

---

## Phase 2 — Knowledge Base

Spawn a single `knowledge-base-builder` agent (foreground, blocks everything else).

**Agent prompt:**
```
You are building a knowledge base for a research project.

Project: $PROJECT at $PROJECT_PATH/$PROJECT
Perspective: $PERSPECTIVE
Topics to research: $TOPICS (joined as comma list)

1. Search for source files: glob `sources/**/*.{tex,md,pdf}` in the project dir and parent directories
2. For each source file found:
   - Extract: title, authors, abstract, key concepts, frameworks, theorems
3. Build a cross-reference section showing how sources relate
4. Write the output to `$PROJECT_PATH/$PROJECT/.knowledge-base.md`

If no source files exist, create a knowledge base from web research on the topics using WebSearch.
The knowledge base should provide enough context for each topic to write a 20+ page paper.
```

Wait for the agent to complete and verify `.knowledge-base.md` exists before proceeding.

---

## Phase 3 — Research Workers (Parallel)

For EACH topic in `$TOPICS`, spawn a `research-worker` agent **in parallel** (all in a single message with multiple Agent tool calls).

**Agent prompt per topic:**
```
You are a research worker writing a paper on: $TOPIC
Perspective: "$PERSPECTIVE, analyze and formalize $TOPIC"
Project root: $PROJECT_PATH/$PROJECT
PROJECT_ROOT=$PROJECT_PATH/$PROJECT
RESEARCH_CODEX_MODEL=$RESEARCH_CODEX_MODEL RESEARCH_CODEX_EFFORT=$RESEARCH_CODEX_EFFORT

Reviewer rules (apply to EVERY "$GEMINI" and "$CODEX" call):
- You have no Skill tool and no Agent tool. Never try to invoke codex:rescue or spawn a subagent; run the direct commands in your agent definition.
- Every single reviewer call is wrapped in the project mutex `$PROJECT_ROOT/.review.lock` (mkdir/rmdir wrapper in your agent definition). Hold it for one call only — never while you edit the paper.
- If the reviewer fails twice, append a BLOCKED line (team/board.md if present, else print it) and exit non-zero. Never self-review, never write a stub file.

[Include exactly one of the next two lines:]
Haskell is ON: create src/$TOPIC/ as described in Stage 1.
Haskell is OFF: write no src/ directory. Skip every Haskell instruction below and report "Haskell: skipped (flag)".

[Only when $MULTI_AGENT_TEAM is true:]
MULTI-AGENT TEAM: ON. Before drafting, write team/$TOPIC/contract.md, log to team/board.md, wait (bounded) for sibling drafts, and reconcile cross-references per references/team-protocol.md (Part numbers: [Part N for this topic; sibling topics and Parts]).

[Only when $HUMAN_READABLE is true:]
HUMAN-READABLE: ON. Apply the humanizer rules in references/team-protocol.md (no em or en dashes, no `---` in prose, no AI-vocabulary words, sentence-case headings, straight quotes, no bold-header bullet lists, neutral scholarly voice) and run its grep checks before your final compile.

[Only when $CODE_AUDIT is true:]
CODE AUDIT: ON. After the Codex formatting loop run Stage 4b (code evidence audit) as defined in your agent definition; every appendix row must be SUPPORTS.

Read .knowledge-base.md for context, then execute this pipeline:

### Stage 1 — Draft
Write an arxiv-style LaTeX paper (>=20 pages) to `papers/latex/$TOPIC.tex`
Include: abstract, introduction, mathematical framework, results, discussion, references.
Use standard article class, amsmath, amssymb, tikz-cd, hyperref, cleveref.
Add custom theorem environments (Theorem, Proposition, Lemma, Definition, Remark).
Keep the paper free of agent activity, review status, confidence labels, provenance fields, audit badges, and internal claim classifications. Use conventional mathematical environments only where they serve the argument.

Author block:
$RESEARCH_AUTHOR_NAME
$RESEARCH_COLLABORATION, $RESEARCH_INSTITUTION
$RESEARCH_LOCATION
$RESEARCH_AUTHOR_EMAIL · $RESEARCH_AUTHOR_URL

If the topic involves mathematics AND Haskell is ON, also create Haskell modules in `src/$TOPIC/`:
- Main.hs with runnable demonstrations
- Supporting modules for key abstractions
- Each file must compile with GHC
(When Haskell is OFF, skip this block entirely.)

### Stages 2–3 — Gemini Review-Fix Loop
Run iterative peer review via the reviewer shim "$GEMINI". Submit paper → fix issues → re-submit until verdict is ACCEPT or MINOR REVISIONS. Max 4 rounds.

Each round: under the .review.lock mutex, run the Bash command that pipes the paper to "$GEMINI" with a review prompt that ends with a VERDICT line (REJECT / MAJOR REVISIONS / MINOR REVISIONS / ACCEPT). Release the lock, then fix. Save each round to `reviews/$TOPIC-review-round-N.md`. Fix critical/major issues between rounds. Copy final review to `reviews/$TOPIC-review.md`. If a review comes back empty, read ${TMPDIR:-/tmp}/agy-review-shim.err before retrying.

See the research-worker agent definition for the exact Bash command and loop logic.

### Stage 4 — Codex LaTeX Formatting Check
Run the direct command from your agent definition (Stage 5 there), under the .review.lock mutex:
    timeout 1200 "$CODEX" exec -m "${RESEARCH_CODEX_MODEL:-gpt-5.6-sol}" -c "model_reasoning_effort=\"${RESEARCH_CODEX_EFFORT:-high}\"" -s read-only --skip-git-repo-check "<concise prompt naming papers/latex/$TOPIC.tex as the only file to read; end with VERDICT: PASS or VERDICT: NEEDS_FIX>" </dev/null >> "$ROUND_FILE" 2>&1
Save rounds to `reviews/$TOPIC-codex-review-round-N.md`, canonical `reviews/$TOPIC-codex-review.md`. Fix all issues. Max 2 fix iterations. (Do NOT try to invoke codex:rescue — you have no Skill tool.)

### Stage 4b — Code Evidence Audit (only when CODE AUDIT: ON)
Codex read-only audit of the paper's code evidence appendix; every row must be judged SUPPORTS. Files: `reviews/$TOPIC-code-audit-round-N.md`, canonical `reviews/$TOPIC-code-audit.md`. Max 2 invocations. See your agent definition (Stage 5b).

### Stage 5 — Add GrokRxiv Sidebar
Add the GrokRxiv DOI sidebar to page 1 of the paper. See references/paper-format.md for the template.
DOI slug: current year.month.$TOPIC
Category: choose appropriate arXiv-style category
Date: today's date

### Stage 6 — Compile PDF
Run these Bash commands:

    cd $PROJECT_PATH/$PROJECT/papers/latex
    pdflatex -interaction=nonstopmode $TOPIC.tex
    pdflatex -interaction=nonstopmode $TOPIC.tex

If compilation fails, read the .log file, fix errors, recompile. Repeat until clean.
Move PDF: `cp $TOPIC.pdf ../pdf/`
Clean artifacts: `rm -f *.aux *.log *.toc *.out *.bbl *.blg *.nav *.snm *.vrb *.fls *.fdb_latexmk *.synctex.gz`

### Stage 7 — Generate Cover Image
Run these Bash commands:

    mkdir -p $PROJECT_PATH/$PROJECT/images
    pdftoppm -png -f 1 -l 1 -r 300 "$PROJECT_PATH/$PROJECT/papers/pdf/$TOPIC.pdf" "$PROJECT_PATH/$PROJECT/images/$TOPIC"
    mv "$PROJECT_PATH/$PROJECT/images/$TOPIC-1.png" "$PROJECT_PATH/$PROJECT/images/$TOPIC.png" 2>/dev/null || true

MANDATORY CHECKLIST — Do NOT proceed to the next stage until each box is done:
[ ] Stage 1: papers/latex/$TOPIC.tex exists and is >=20 pages
[ ] Stages 2–3: reviews/$TOPIC-review.md exists with Gemini ACCEPT/MINOR REVISIONS verdict
[ ] Stage 4: Codex formatting check run via direct "$CODEX" exec command, issues fixed
[ ] Stage 4b (CODE AUDIT only): reviews/$TOPIC-code-audit.md exists, every row SUPPORTS
[ ] Stage 5: GrokRxiv sidebar added to page 1
[ ] Stage 6: papers/pdf/$TOPIC.pdf exists and compiles cleanly
[ ] Stage 7: images/$TOPIC.png exists (300 DPI cover)

When complete, report: topic name, paper page count, whether Haskell code was created, PDF compilation status, Gemini review (rounds completed, final verdict), Codex issues (count found → count fixed).
```

**MANDATORY — Post-Worker Review Hard Gate:**

After ALL workers complete, run the strict review gate below. This is a HARD GATE — if any check fails, the orchestrator must **respawn the worker** for that topic (not "inline the loop yourself" — that path was removed because it was also being skipped). If the respawn still fails the gate, **abort the pipeline** with a clear failure summary. Do NOT proceed to Phase 4 with missing/stub reviews.

Paste this gate function once, then call it per topic:

```bash
# Strict review gate — covers (a) missing files, (b) SKIPPED stubs,
# (c) round-1-only with non-publishable verdict, (d) header-only Codex files.
review_gate_check() {
  local topic="$1"
  local size csize rounds final_verdict

  test -f "reviews/$topic-review-round-1.md" \
    || { echo "FAIL ($topic): reviews/$topic-review-round-1.md MISSING — Gemini skipped entirely"; return 1; }
  ! grep -q "^SKIPPED:" "reviews/$topic-review-round-1.md" \
    || { echo "FAIL ($topic): round-1 file is a SKIPPED stub"; return 1; }
  size=$(wc -c < "reviews/$topic-review-round-1.md")
  [ "$size" -ge 500 ] \
    || { echo "FAIL ($topic): round-1 only ${size}B — Gemini output not appended"; return 1; }

  test -f "reviews/$topic-review.md" \
    || { echo "FAIL ($topic): canonical reviews/$topic-review.md MISSING"; return 1; }
  ! grep -q "^SKIPPED:" "reviews/$topic-review.md" \
    || { echo "FAIL ($topic): canonical review is a SKIPPED stub"; return 1; }
  grep -q "VERDICT:" "reviews/$topic-review.md" \
    || { echo "FAIL ($topic): canonical review has no VERDICT line"; return 1; }

  # (c) Verdict trajectory: final must be ACCEPT/MINOR, OR 4-round cap reached.
  final_verdict=$(tail -20 "reviews/$topic-review.md" | grep -i "VERDICT" | tail -1)
  rounds=$(ls reviews/$topic-review-round-*.md 2>/dev/null | wc -l | tr -d ' ')
  case "$final_verdict" in
    *ACCEPT*|*MINOR*) ;;
    *)
      if [ "$rounds" -lt 4 ]; then
        echo "FAIL ($topic): final verdict='$final_verdict' but only $rounds round(s) — worker did not iterate"
        return 1
      fi
      ;;
  esac

  # (d) Codex canonical review must exist and be substantive.
  test -f "reviews/$topic-codex-review.md" \
    || { echo "FAIL ($topic): reviews/$topic-codex-review.md MISSING — Codex skipped entirely"; return 1; }
  ! grep -q "^SKIPPED:" "reviews/$topic-codex-review.md" \
    || { echo "FAIL ($topic): codex review is a SKIPPED stub"; return 1; }
  csize=$(wc -c < "reviews/$topic-codex-review.md")
  [ "$csize" -ge 500 ] \
    || { echo "FAIL ($topic): codex review only ${csize}B — Codex output not appended"; return 1; }
  grep -q "VERDICT:" "reviews/$topic-codex-review.md" \
    || { echo "FAIL ($topic): codex review has no VERDICT line"; return 1; }

  echo "PASS ($topic): Gemini=$rounds round(s) verdict='$final_verdict', Codex=${csize}B"
  return 0
}

echo "=== POST-WORKER REVIEW GATE ==="
gate_fail_topics=()
for topic in $TOPICS; do
  review_gate_check "$topic" || gate_fail_topics+=("$topic")
done
echo "=== GATE SUMMARY ==="
echo "Failed topics: ${gate_fail_topics[*]:-none}"
```

**If any topic fails the gate**, do exactly this — no shortcuts:

1. **Respawn the research-worker for that topic** with `mode: "bypassPermissions"` and this corrective prompt prefix:

   > Your previous run skipped the mandatory review stages. Review files are missing, stub-only, or did not iterate to a publishable verdict. **Re-run starting at Stage 3 (Gemini Review-Fix Loop) and continuing through Stage 5 (Codex Formatting Review-Fix Loop).** Do NOT redo Stages 1–2 — the LaTeX source already exists. Both Gemini and Codex stages are MANDATORY and must produce real review files with VERDICT lines.

2. **Re-run `review_gate_check "$topic"` after the respawn.**
3. **If it still fails after the respawn**, abort the pipeline:

   ```bash
   echo "FATAL: review gate still failing for: ${gate_fail_topics[*]}"
   echo "Pipeline aborted at Phase 3 — cannot proceed to synthesis with un-reviewed papers."
   exit 1
   ```

The "run the review loop yourself" fallback that lived here previously was removed because it was being skipped just as often as the worker's own loop. Respawning the worker (which has the loop logic) is the correct correction; aborting on second failure prevents the pipeline from shipping un-reviewed papers.

**BLOCKED workers — orchestrator runs the external referee.** A worker whose reviewer failed twice exits non-zero after appending a `BLOCKED` line (to `team/board.md` when it exists, otherwise in its output). Sub-agents have no Agent tool, so the referee fallback runs HERE, not inside the worker:

1. Read `${TMPDIR:-/tmp}/agy-review-shim.err` and `rmdir "$PROJECT_PATH/$PROJECT/.review.lock" 2>/dev/null` (a crashed worker can leave the lock behind).
2. Re-run the Step 1b reviewer sanity test. If it passes, respawn the worker from Stage 3 (corrective prompt above).
3. If it still fails, spawn a `general-purpose` agent (`mode: "bypassPermissions"`) as a hostile external referee: pass the full paper source inline, require severity-structured output ending in a VERDICT line, write it to the same `reviews/$TOPIC-review-round-N.md` with `reviewer: subagent-referee-fallback` in the frontmatter, then respawn the worker from Step C of Stage 3 so it applies the fixes. Self-review and stub files remain prohibited.

**Integration reviewer gate (only when `--multi-agent-team`)** — runs after the post-worker gate passes and BEFORE Phase 4. Spawn one `general-purpose` agent (`mode: "bypassPermissions"`) with all `papers/latex/*.tex`, every `team/<slug>/contract.md`, and `team/board.md` inline; it checks that shared objects are defined once by their owning Part (lower-numbered Part owns a shared object), that every `Part N` cross-reference resolves to a theorem or definition that exists in that Part, and that notation matches the contracts. It writes `team/integration-review.md` ending with `VERDICT: INTEGRATED` or `VERDICT: CONFLICTS` plus a list `(<slug>, <object>, <fix>)`. On CONFLICTS, respawn only the affected workers with the fix list (starting at Stage 3), then re-run the integration reviewer. Max 2 rounds; abort on a second CONFLICTS. Protocol details: `references/team-protocol.md`.

**MANDATORY — Slack notification per completed topic:**

After EACH worker completes (not after all — after EACH one), immediately send a Slack notification using `mcp__claude_ai_Slack__slack_send_message` to channel `$SLACK_CHANNEL`:

```
Research paper completed: $TOPIC
Pages: [count]
PDF: papers/pdf/$TOPIC.pdf
Haskell: [yes/no]
Gemini review: [N] rounds, final verdict: [ACCEPT/MINOR REVISIONS/etc]
Codex check: [issues found] → [issues fixed]
Review files: reviews/$TOPIC-review-round-*.md
```

---

## Phase 4 — Synthesis Agent

After ALL research workers complete, spawn `synthesis-agent` (foreground):

**Agent prompt:**
```
You are a synthesis agent combining multiple research papers into a unified work.

Project root: $PROJECT_PATH/$PROJECT
PROJECT_ROOT=$PROJECT_PATH/$PROJECT
RESEARCH_CODEX_MODEL=$RESEARCH_CODEX_MODEL RESEARCH_CODEX_EFFORT=$RESEARCH_CODEX_EFFORT
Perspective: $PERSPECTIVE
Topics: $TOPICS (all of them)

Reviewer rules: you have no Skill tool and no Agent tool — never try codex:rescue or a subagent; run the direct "$GEMINI" / "$CODEX" commands in your agent definition, each single call wrapped in the $PROJECT_ROOT/.review.lock mutex. If a reviewer fails twice, append a BLOCKED line (team/board.md if present, else print it) and exit non-zero.
[When $HUMAN_READABLE is true add:] HUMAN-READABLE: ON. Apply the humanizer rules in references/team-protocol.md.

1. Read ALL papers in papers/latex/*.tex
2. Read .knowledge-base.md
3. Write papers/latex/synthesis.tex — a synthesis paper that:
   - Unifies all topics under the perspective
   - Identifies cross-cutting themes and emergent properties
   - References individual papers as Parts I, II, III, etc.
   - Shows how topics compose hierarchically
   - Minimum 20 pages, arxiv-style

4. Run Gemini peer review (same as workers — "$GEMINI" -m $RESEARCH_GEMINI_MODEL under the mutex)
5. Fix review issues (max 2 iterations)
6. Run the Codex LaTeX check with the direct command (timeout 1200 "$CODEX" exec -m "${RESEARCH_CODEX_MODEL:-gpt-5.6-sol}" -c "model_reasoning_effort=\"${RESEARCH_CODEX_EFFORT:-high}\"" -s read-only --skip-git-repo-check "<concise prompt: read only papers/latex/synthesis.tex; end with VERDICT: PASS or VERDICT: NEEDS_FIX>" </dev/null >> "$ROUND_FILE" 2>&1) under the mutex, fix issues
7. Add GrokRxiv sidebar
8. Compile PDF (pdflatex twice, fix errors)
9. Generate cover image (pdftoppm)

Author block same as worker papers.
```

**MANDATORY — Synthesis Review Hard Gate:**

After the synthesis-agent returns, run the same review gate semantics with `synthesis` as the topic. The `review_gate_check` function defined in Phase 3 works as-is — call it with `"synthesis"`:

```bash
echo "=== POST-SYNTHESIS REVIEW GATE ==="
review_gate_check "synthesis" || {
  echo "Synthesis review gate FAILED — respawning synthesis-agent with corrective prompt..."
  # Respawn synthesis-agent with this prefix, then re-run the gate.
  # If it fails twice, abort:
  #   echo "FATAL: synthesis review gate still failing"; exit 1
}
```

Respawn prompt prefix (same shape as the Phase 3 corrective prompt): *"Your previous run skipped the mandatory review stages for the synthesis paper. Re-run starting at step 5 (Gemini Review-Fix Loop) through step 7 (Codex Formatting Review-Fix Loop). Do NOT redo steps 1–4 — the LaTeX source already exists."* On second failure, `exit 1`.

**Synthesis checkpoint before proceeding:**
- [ ] papers/latex/synthesis.tex exists and is >=20 pages
- [ ] `review_gate_check "synthesis"` returns PASS
- [ ] GrokRxiv sidebar added
- [ ] papers/pdf/synthesis.pdf compiles cleanly
- [ ] images/synthesis.png cover image generated

**MANDATORY — Slack notification on synthesis completion** using `mcp__claude_ai_Slack__slack_send_message` to `$SLACK_CHANNEL`:
```
Synthesis paper completed
Topics unified: [list]
Pages: [count]
Gemini review: [issues found] → [issues fixed]
Codex check: [issues found] → [issues fixed]
```

---

## Phase 4.5 — Optional Pre-Compile Gates (`--bib-gate`, `--human-readable`)

Both gates run in the orchestrator (workers and synthesis are done, Phase 6 has not converted anything yet). Any paper edited here MUST be recompiled (`pdflatex` twice, copy to `papers/pdf/`) before Phase 6 — Phase 8b's freshness check catches stragglers, but the website conversion reads the `.tex`, so do it now.

**Bibliography gate (only when `--bib-gate`).** For every `papers/latex/*.tex` (and `.bib` files if used), list each bibliography entry that carries an arXiv id, DOI, or URL. Resolve each with `WebFetch` (`https://arxiv.org/abs/<id>`, `https://doi.org/<doi>`, or the URL). An entry resolves when the page exists and its title matches the entry (allow minor punctuation differences). Write results to `team/<slug>/bib-check.md` when `team/` exists, otherwise `reviews/<slug>-bib-check.md`, one line per entry: `OK | MISSING | MISMATCH  <key>  <target>  <note>`. Every MISSING/MISMATCH entry is then removed from the paper (and its `\cite` sites rewritten) or replaced by a resolvable reference. The gate passes only when the file has zero MISSING/MISMATCH lines.

**Human-readable checks (only when `--human-readable`).** Run the grep checks in `references/team-protocol.md` ("Humanizer grep checks") over every `papers/latex/*.tex`. Fix every hit by editing the prose (not by adding exceptions), then re-run until clean. Record the final clean run in `reviews/human-readable-check.md`.

---

## Phase 5 — Haskell Verification

**Skip if `$SKIP_HASKELL` is true.**

For each topic that has code in `src/$TOPIC/`, spawn `haskell-verifier` agents in parallel:

**Agent prompt per topic:**
```
You are a Haskell formal verification agent using a layered proof strategy.

Project root: $PROJECT_PATH/$PROJECT
PROJECT_ROOT=$PROJECT_PATH/$PROJECT
RESEARCH_CODEX_MODEL=$RESEARCH_CODEX_MODEL RESEARCH_CODEX_EFFORT=$RESEARCH_CODEX_EFFORT
Topic: $TOPIC
Source directory: src/$TOPIC/

You have no Skill tool — never try to invoke codex:rescue. Run the direct "$CODEX" exec command from your agent definition, each call wrapped in the $PROJECT_ROOT/.review.lock mutex.

PHASE 1 — Structure and Compilation:
1. Read all .hs files in src/$TOPIC/
2. Ensure these modules exist: Main.hs, Core.hs (or domain-named), Properties.hs, Proofs.hs
3. If Properties.hs or Proofs.hs don't exist, CREATE them:
   - Properties.hs: QuickCheck properties for each major theorem in the paper
   - Proofs.hs: Equational reasoning proofs with executable checks
4. Compile with strict flags:

       cd $PROJECT_PATH/$PROJECT && ghc -Wall -Wextra -Werror -o src/$TOPIC/test src/$TOPIC/Main.hs src/$TOPIC/*.hs -isrc/$TOPIC -package QuickCheck 2>&1

5. Fix compilation errors (max 3 iterations)

PHASE 2 — QuickCheck Property Testing:
6. Ensure Properties.hs has at least one property per major theorem/proposition
7. Compile and run properties:

       cd $PROJECT_PATH/$PROJECT && ghc -Wall -o src/$TOPIC/props src/$TOPIC/Properties.hs -isrc/$TOPIC -package QuickCheck 2>&1 && src/$TOPIC/props

8. All properties MUST pass. If any fail, fix the implementation and rerun.

PHASE 3 — Equational Reasoning:
9. Ensure Proofs.hs contains equational proofs in structured format
10. Each proof must cite which paper theorem it verifies
11. Run proof checks via Main.hs

PHASE 4 — Liquid Haskell (optional):
12. Check if Liquid Haskell is available: `which liquid`
13. If available, add refinement type annotations and run `liquid src/$TOPIC/Core.hs`
14. If not available, skip and note in report

PHASE 5 — Codex Review:
15. Under the mutex, run: timeout 1200 "$CODEX" exec -m "${RESEARCH_CODEX_MODEL:-gpt-5.6-sol}" -c "model_reasoning_effort=\"${RESEARCH_CODEX_EFFORT:-high}\"" -s read-only --skip-git-repo-check "Review only the Haskell files in src/$TOPIC/ (do not explore other directories) for: type safety, QuickCheck property correctness, equational proof soundness, missing coverage, idiomatic style. End with VERDICT: PASS or VERDICT: NEEDS_FIX." </dev/null >> "$ROUND_FILE" 2>&1
16. Fix issues (max 2 iterations); round files reviews/$TOPIC-haskell-codex-review-round-N.md, canonical reviews/$TOPIC-haskell-codex-review.md

PHASE 6 — Final Verification:
17. Recompile everything, rerun all properties and proofs
18. Main.hs must exit 0 (all verifications pass)
19. Clean up: `rm -f src/$TOPIC/test src/$TOPIC/props src/$TOPIC/*.o src/$TOPIC/*.hi`

Report: compilation status, QuickCheck (N properties, all passed/failures), equational proofs (N checked/passed), Liquid Haskell (verified/skipped), Codex issues fixed.
```

**MANDATORY — Haskell Codex Review Hard Gate:**

After haskell-verifier agents complete, verify each topic's Haskell Codex review file passes the same substantive-content checks. Run this gate per topic:

```bash
haskell_review_gate() {
  local topic="$1" csize
  test -d "src/$topic" || { echo "SKIP ($topic): no src/$topic/ directory"; return 0; }
  test -f "reviews/$topic-haskell-codex-review.md" \
    || { echo "FAIL ($topic): reviews/$topic-haskell-codex-review.md MISSING — Codex skipped entirely"; return 1; }
  ! grep -q "^SKIPPED:" "reviews/$topic-haskell-codex-review.md" \
    || { echo "FAIL ($topic): haskell codex review is a SKIPPED stub"; return 1; }
  csize=$(wc -c < "reviews/$topic-haskell-codex-review.md")
  [ "$csize" -ge 500 ] \
    || { echo "FAIL ($topic): haskell codex review only ${csize}B — Codex output not appended"; return 1; }
  grep -q "VERDICT:" "reviews/$topic-haskell-codex-review.md" \
    || { echo "FAIL ($topic): haskell codex review has no VERDICT line"; return 1; }
  echo "PASS ($topic): haskell Codex=${csize}B"
  return 0
}

echo "=== POST-HASKELL REVIEW GATE ==="
hs_fail_topics=()
for topic in $TOPICS; do
  haskell_review_gate "$topic" || hs_fail_topics+=("$topic")
done
```

**If any topic fails**, respawn the haskell-verifier for that topic with the corrective prompt: *"Your previous run skipped the mandatory Codex review (Phase 5). Re-run starting at Phase 5 (Codex Review-Fix Loop) and Phase 6 (Final Verification). Do NOT redo Phases 1–4 — Haskell source and proofs already exist."* Re-run the gate; on second failure, `exit 1`.

**Haskell checkpoint before proceeding:**
- [ ] All src/$TOPIC/ directories compile with `-Wall -Wextra -Werror` and zero warnings
- [ ] Properties.hs exists with QuickCheck properties for major theorems — all pass
- [ ] Proofs.hs exists with equational reasoning proofs — all executable checks pass
- [ ] Main.hs exits 0 (all verifications pass)
- [ ] `haskell_review_gate $topic` returns PASS for every topic with Haskell source

**MANDATORY — Slack notification on Haskell verification completion** using `mcp__claude_ai_Slack__slack_send_message` to `$SLACK_CHANNEL`:
```
Haskell verification completed
Topics verified: [list]
Modules compiled: [count]
QuickCheck: [N] properties tested, [N] passed
Equational proofs: [N] checked, [N] passed
Liquid Haskell: [verified/skipped]
Codex issues fixed: [count]
```

---

## Phase 6 — Website Build

**Skip if `$SKIP_WEBSITE` is true.**

### Step 6a — Pandoc Conversion

Convert all papers (including synthesis) to HTML. Run this Bash command:

    cd $PROJECT_PATH/$PROJECT
    for tex in papers/latex/*.tex; do
      name=$(basename "$tex" .tex)
      pandoc "$tex" --to html5 --mathjax --toc --toc-depth=3 --number-sections --no-highlight --wrap=none -o "docs/papers/$name.html"
    done

NOTE: Use `--mathjax` (not `--katex`) for pandoc conversion. This wraps math in `\(...\)` and `\[...\]` delimiters that KaTeX renderToString() can process at build time. The `--katex` flag inlines KaTeX HTML which often breaks complex expressions.

**MANDATORY — Extract custom LaTeX macros before math rendering:**
Papers define custom commands via `\newcommand` in their preambles (e.g. `\newcommand{\Hilb}{\mathcal{H}}`). These MUST be extracted and passed to KaTeX as macros, otherwise they render as red error text.

1. Parse all `papers/latex/*.tex` for `\newcommand{\name}[args]{definition}` lines
2. Convert each to a KaTeX macro entry: `'\\name': 'definition'`
3. Merge with base macros (`\slashed`, `\bra`, `\ket`, `\braket`, `\Hom`, `\Tr`, etc.)
4. Pass the full macro map to `katex.renderToString()` in `lib/render-math.ts`

This is critical — research papers routinely define 50-70 custom commands. Missing ANY of them causes visible red errors on the website.

If `scripts/latex2html.py` exists, prefer using it for better post-processing:

    python3 scripts/latex2html.py --latex-dir papers/latex --html-dir docs/papers --template scripts/paper-template.html --project-title "$PROJECT" --papers "topic:Title:Part N" ...

**MANDATORY — Math verification after conversion:**
For each converted HTML file, check for broken math by searching for raw LaTeX that wasn't wrapped in math delimiters:

    cd $PROJECT_PATH/$PROJECT/docs/papers
    for html in *.html; do
      echo "=== $html ==="
      # Find raw LaTeX commands outside of math delimiters
      grep -oP '(?<![\\(\[])\\(textbf|textit|mathcal|frac|sqrt|sum|prod|int|partial|nabla|infty|alpha|beta|gamma|delta|epsilon|lambda|mu|sigma|omega|psi|phi|Psi|Phi|mathbb|mathrm|operatorname|slashed|bar|hat|tilde|vec)\b' "$html" | head -20
    done

Fix any raw LaTeX found outside math delimiters by wrapping in `\(...\)` for inline or `\[...\]` for display math. Common issues to fix:
- `$$...$$` not converted: replace with `\[...\]`
- Inline `$...$` not converted: replace with `\(...\)`
- `\textbf{}` outside math: convert to `<strong>`
- `\textit{}` outside math: convert to `<em>`
- `\slashed{D}` — KaTeX doesn't support `\slashed`: replace with `\not{D}` or `{D\!\!\!/}`
- Subscripts/superscripts in prose (e.g. `SU(2)_L`): wrap in `\(...\)`

### Step 6b — Next.js Website

Spawn `website-builder` agent (foreground):

**Agent prompt:**
```
You are building a modern, mobile-ready research website with a UNIQUE theme derived from the research topics.

Project root: $PROJECT_PATH/$PROJECT
Papers: [list all topics + synthesis with titles]
Perspective: $PERSPECTIVE
Topics: $TOPICS
GitHub org: $GITHUB_ORG
Project name: $PROJECT

## STEP 0 — Design a Topic-Driven Theme

DO NOT use generic colors. Design a unique color palette and visual identity based on the research topics and perspective. Follow this process:

1. Analyze the research domain:
   - Physics/quantum: deep blues, ultraviolet, particle-trail glows
   - Mathematics/category theory: geometric purples, abstract gradients
   - Biology/neuroscience: organic greens, neural network patterns
   - Computer science/AI: electric cyan, circuit-board motifs
   - Chemistry: molecular oranges, reaction-energy yellows
   - Cosmology/gravity: dark space blacks, nebula gradients, stellar golds
   - Economics/social: warm earth tones, network graphs
   - Philosophy/epistemology: deep magentas, contemplative dark palettes

2. Generate a CSS variables block with these required tokens:
   --bg:            (dark background — always dark for readability)
   --surface:       (slightly lighter than bg, for cards/panels)
   --surface-hover: (hover state for surface elements)
   --accent:        (primary accent — derived from topic domain)
   --accent-hover:  (lighter variant of accent)
   --accent-glow:   (accent at ~15% opacity, for subtle glows)
   --accent-secondary: (complementary accent for variety)
   --text:          (light text on dark bg — high contrast)
   --text-muted:    (secondary text)
   --text-dim:      (tertiary/disabled text)
   --border:        (subtle borders)
   --code-bg:       (code block background, darker than bg)
   --success:       (status color)
   --warning:       (status color)

3. Design topic-specific visual touches:
   - Hero section gradient or pattern that evokes the research domain
   - Card hover effects that match the topic energy (e.g. glow for quantum, grow for biology)
   - A subtle background texture or SVG pattern relevant to the field
   - Typography choices that match the tone (e.g. serif for classical physics, sans for CS)

4. Write the complete theme to `website/theme.json` so it can be referenced:
   {
     "name": "theme-name-based-on-topics",
     "domain": "detected research domain",
     "colors": { "bg": "#...", "accent": "#...", ... },
     "font": "Inter|Crimson Pro|JetBrains Mono|...",
     "heroGradient": "linear-gradient(...)",
     "cardEffect": "glow|grow|slide|fade",
     "bgPattern": "description of SVG/CSS pattern"
   }

## STEP 1 — Create Next.js Project

Run this Bash command:

    cd $PROJECT_PATH/$PROJECT && npx create-next-app@14 website --typescript --tailwind --app --no-src-dir --no-import-alias --use-npm

## STEP 2 — Build Pages

**app/layout.tsx**: Root layout with:
- Topic-appropriate font from next/font/google (chosen in theme)
- Dark theme using the generated CSS variables
- Global OG meta tags
- Navigation header with project title

**app/page.tsx**: Landing page with:
- Hero section with topic-driven gradient/pattern and project title
- Brief perspective description
- Paper cards grid (responsive: 1 col mobile, 2 col tablet, 3 col desktop)
- Each card: cover image, title, part number, abstract excerpt (first 150 chars)
- Card hover effects matching the topic theme
- Links: "Read" (HTML page), "PDF" (download), "Code" (GitHub src link)

**app/papers/[slug]/page.tsx**: Individual paper pages with:
- Full paper content from pandoc HTML, math pre-rendered server-side via katex.renderToString() (NOT client-side useEffect), then sanitized with DOMPurify
- KaTeX CSS imported for font rendering (npm package, not CDN)
- Sticky sidebar TOC generated from h2/h3 headings (collapse to hamburger on mobile)
- PDF download button (fixed position)
- Previous/Next paper navigation
- Per-page OG meta tags via generateMetadata()
- Themed code blocks and theorem environments matching the domain

**app/globals.css**: Generated theme CSS variables + Tailwind base + custom paper content styles (theorem blocks, code blocks, math display, tables) using the topic-driven palette

**public/**: Copy papers/pdf/*.pdf, images/*.png, docs/papers/*.html content

## STEP 3 — Data and Config

- Create papers.json manifest listing all papers with metadata (slug, title, part, abstract, pages, hasCode, category)
- Install DOMPurify: `npm install isomorphic-dompurify`
- Configure next.config.js with: output: 'export', images: { unoptimized: true }

## Quality Requirements
- Fully responsive and readable on mobile (no horizontal scroll)
- Papers must render math correctly via KaTeX
- Dark theme throughout — NEVER use white/light backgrounds
- Fast loading (static export, no client-side data fetching)
- Professional research aesthetic — the design must feel UNIQUE to this research domain, not like a generic template
- Each project's website should be visually distinguishable from other projects
```

### Step 6c — OG Image Generation (DESIGNED CARDS, not letterboxed thumbnails)

Spawn `og-image-generator` agent (can run in parallel with website-builder). The agent has been rewritten to produce **designed 1200x630 social cards** (gradient background + rendered title text + accent stripe + project tag) using ImageMagick. A letterboxed PDF thumbnail is a PIPELINE FAILURE — see Step 6c.5 below for the gate.

**Agent prompt:**
```
Generate Open Graph images (1200x630) for each research paper as DESIGNED social cards (NOT letterboxed PDF thumbnails).

Project root: $PROJECT_PATH/$PROJECT
Project slug: $PROJECT
Papers: [list of topic slugs, comma-separated]

Follow the og-image-generator agent definition exactly:
1. Resolve ImageMagick (`magick` or legacy `convert`). FAIL the agent if missing.
2. Read theme colors from website/theme.json.
3. For each topic, extract `\title{...}` from papers/latex/$TOPIC.tex (or humanize the slug if missing) and render a 1200x630 card using the `caption:` pseudo-format for auto-wrapping title text.
4. Render a landing card website/public/og/og-default.png with the project name + topic count subtitle.
5. Verify each output: dimensions == 1200 630, file size >= 30KB, ImageMagick std-dev > 0.08 (rejects flat/letterboxed canvases).
6. Print a per-file PASS/FAIL summary.

DO NOT fall back to `sips` (cannot render text). DO NOT just resize images/$TOPIC.png onto a black canvas — that is the regression we are fixing.
```

### Step 6c.5 — OG Validation Gate (MANDATORY)

After the agent returns, validate every OG image BEFORE Step 6d. This catches the letterboxed-thumbnail regression at the source instead of letting it propagate to Slack/social cards.

```bash
cd $PROJECT_PATH/$PROJECT
MAGICK="$(command -v magick 2>/dev/null || command -v convert 2>/dev/null)"
[ -n "$MAGICK" ] || { echo "FAIL: ImageMagick missing — cannot validate OG images"; exit 1; }

og_fail=0
for f in website/public/og/*.png; do
  dims=$("$MAGICK" identify -format "%w %h" "$f")
  size=$(stat -f %z "$f" 2>/dev/null || stat -c %s "$f")
  std=$("$MAGICK" identify -format "%[fx:standard_deviation]" "$f" 2>/dev/null)
  [ "$dims" = "1200 630" ] || { echo "FAIL ($f): dims=$dims (need 1200 630)"; og_fail=1; continue; }
  [ "$size" -ge 30000 ]    || { echo "FAIL ($f): size=${size}B (need >=30KB)"; og_fail=1; continue; }
  awk -v s="$std" 'BEGIN { exit !(s+0 < 0.08) }' && { echo "FAIL ($f): std=$std (looks letterboxed/flat)"; og_fail=1; continue; }
  echo "PASS ($f): ${dims//[[:space:]]/x}, ${size}B, std=$std"
done

[ "$og_fail" = 0 ] || { echo "OG VALIDATION FAILED — re-spawn og-image-generator before deploying"; exit 1; }
echo "OG VALIDATION: PASS"
```

If this gate fails, re-spawn `og-image-generator` (same prompt). Do not proceed to Step 6d/6e until every OG image passes.

### Step 6d — Codex Website Review (MANDATORY — do NOT skip)

This step is REQUIRED. After the website is built and BEFORE deploying to Vercel, invoke the `codex:rescue` skill (the orchestrator has the Skill tool, so this is the one place `codex:rescue` is still used; the direct command below is equivalent and PREFERRED whenever a specific model or effort is requested):

```bash
cd $PROJECT_PATH/$PROJECT
LOCK="$PROJECT_PATH/$PROJECT/.review.lock"
until mkdir "$LOCK" 2>/dev/null; do sleep 30; done; trap 'rmdir "$LOCK" 2>/dev/null' EXIT
timeout 1200 "$CODEX" exec -m "${RESEARCH_CODEX_MODEL:-gpt-5.6-sol}" -c "model_reasoning_effort=\"${RESEARCH_CODEX_EFFORT:-high}\"" -s read-only --skip-git-repo-check "Review only the files under website/app, website/lib, website/components and website/out (do not explore papers/, src/ or reviews/) for the checklist below. End with VERDICT: PASS or VERDICT: NEEDS_FIX. <paste the checklist>" </dev/null >> reviews/website-codex-review-round-1.md 2>&1
rmdir "$LOCK" 2>/dev/null; trap - EXIT
```

Review prompt (paste into `codex:rescue` or the direct command):

```
Review the Next.js research website at $PROJECT_PATH/$PROJECT/website/ for:
- HTML readability issues (semantic HTML, heading hierarchy, ARIA labels)
- Layout bugs (overflow, z-index conflicts, flex/grid issues)
- Design errors (contrast ratios, font sizes, spacing inconsistencies)
- Mobile responsiveness (touch targets, viewport issues, text readability)
- Broken links or missing assets
- KaTeX math rendering: check that math is pre-rendered server-side (katex.renderToString), NOT client-side (useEffect). Check for raw LaTeX in the static HTML output.
- Sidebar TOC: verify active section tracking uses scroll position (last heading above viewport), NOT IntersectionObserver with narrow rootMargin. Active item must highlight correctly when scrolling through long sections.
- Scroll behavior: check all scroll-dependent features work in static export (no JS on first load for SSG)
- React hydration: verify paper content uses ref callback with node.innerHTML to avoid KaTeX HTML hydration mismatches. Do NOT use React's built-in HTML insertion — it mangles KaTeX spans.
- OG meta tags: verify metadataBase is set in root layout (required for absolute OG URLs). Check that every paper page has og:image, og:url, og:title, og:description AND twitter:card + twitter:images in generateMetadata(). Homepage must have its own OG image too. Missing metadataBase = broken social previews on Facebook/LinkedIn/Twitter.
- After build, grep static HTML in out/ for og:image and twitter:card tags — every paper page must have them with absolute URLs.
- Performance issues (large bundles, unoptimized images)
List all issues with file paths and line numbers.
```

Fix all Codex-identified issues. Maximum 2 fix iterations. Log the number of issues found and fixed.

### Step 6e — Vercel Deployment

**CRITICAL — Name the Vercel project after `$PROJECT`, not `website`.** The local directory is `website/`, but the Vercel project (and the `<slug>.vercel.app` URL) MUST be derived from `$PROJECT`. Without explicit naming, Vercel uses the current directory name (`website`), producing URLs like `website-abc123.vercel.app` and a fresh project on every run.

Run these Bash commands:

    cd $PROJECT_PATH/$PROJECT/website

    # Derive a Vercel-safe project name from $PROJECT (lowercase, [a-z0-9-], <=100 chars)
    VERCEL_PROJECT=$(echo "$PROJECT" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9-]+/-/g; s/^-+|-+$//g' | cut -c1-100)

    npm run build

    # Create the Vercel project (idempotent) and link this dir to it BEFORE deploying
    npx vercel project add "$VERCEL_PROJECT" 2>/dev/null || true
    npx vercel link --yes --project "$VERCEL_PROJECT" 2>&1 | tee /tmp/vercel-link.log

**MANDATORY — Fix the project settings BEFORE the first deploy.** Projects created by `vercel project add` get **framework None** (the remote build serves 404 everywhere) and **SSO Deployment Protection** (every request 302s to `vercel.com/sso`). Patch both via the REST API using the CLI's own token and the ids `vercel link` just wrote, then build locally and deploy prebuilt:

    # Token from the Vercel CLI auth store; ids from the link step
    VERCEL_TOKEN=$(python3 -c 'import json,os;print(json.load(open(os.path.expanduser("~/Library/Application Support/com.vercel.cli/auth.json")))["token"])')
    VERCEL_PROJECT_ID=$(python3 -c 'import json;print(json.load(open(".vercel/project.json"))["projectId"])')
    VERCEL_ORG_ID=$(python3 -c 'import json;print(json.load(open(".vercel/project.json"))["orgId"])')
    [ -n "$VERCEL_TOKEN" ] && [ -n "$VERCEL_PROJECT_ID" ] && [ -n "$VERCEL_ORG_ID" ] || { echo "FAIL: missing Vercel token/ids — did vercel link succeed?"; exit 1; }

    curl -sS -X PATCH "https://api.vercel.com/v9/projects/${VERCEL_PROJECT_ID}?teamId=${VERCEL_ORG_ID}" \
      -H "Authorization: Bearer $VERCEL_TOKEN" -H "Content-Type: application/json" \
      -d '{"framework":"nextjs","ssoProtection":null}' | tee /tmp/vercel-patch.log | grep -q '"framework":"nextjs"' \
      && echo "PROJECT SETTINGS OK" || { echo "FAIL: project PATCH did not apply — see /tmp/vercel-patch.log"; exit 1; }

    # Pull production settings, build locally, deploy the prebuilt output
    npx vercel pull --yes --environment=production 2>&1 | tee /tmp/vercel-pull.log
    npx vercel build --prod 2>&1 | tee /tmp/vercel-build.log
    npx vercel deploy --prebuilt --prod 2>&1 | tee /tmp/vercel-deploy.log

The clean production alias is `https://<project>.vercel.app` (i.e. `https://$VERCEL_PROJECT.vercel.app`); the deploy log also prints a hashed deployment URL. Prefer the clean alias for `.vercel-url` when it responds 200 (check below), otherwise fall back to the extracted deployment URL.

**MANDATORY — Extract, validate, and persist the Vercel URL:**

The Vercel CLI output contains the production URL. **NEVER guess or construct the URL from the project name** — Vercel assigns its own subdomain which rarely matches.

Extract and save to disk with this single command block:

    VERCEL_URL=$(grep -oE 'https://[a-zA-Z0-9._-]+\.vercel\.app' /tmp/vercel-deploy.log | tail -1)
    # Prefer the clean production alias when it is live (no SSO redirect, no 404)
    ALIAS_URL="https://$VERCEL_PROJECT.vercel.app"
    if [ "$(curl -s -o /dev/null -w '%{http_code}' "$ALIAS_URL")" = "200" ]; then VERCEL_URL="$ALIAS_URL"; fi
    echo "$VERCEL_URL" > $PROJECT_PATH/$PROJECT/.vercel-url
    echo "Extracted URL: $VERCEL_URL"

**GATE CHECK — Validate before proceeding:**

    URL=$(cat $PROJECT_PATH/$PROJECT/.vercel-url)
    echo "$URL" | grep -qE '^https://[a-zA-Z0-9._-]+\.vercel\.app$' && echo "URL OK: $URL" || echo "URL INVALID: $URL"
    echo "$URL" | grep -q '\.xn--' && echo "FAIL: punycode detected" || echo "PASS: no punycode"
    curl -sI "$URL" | head -1

The URL must:
1. End in `.vercel.app` (plain ASCII, no punycode like `.xn--`)
2. Be a valid HTTPS URL with no trailing special characters
3. Return `HTTP/2 200` or `HTTP/2 308` from curl — a `302` to `vercel.com/sso` means the PATCH above did not clear `ssoProtection`; a `404` on `/` means framework is still None. Re-run the PATCH and redeploy.
4. **Contain `$VERCEL_PROJECT` as a prefix** — i.e. `https://<project>[-<hash>].vercel.app`, never `https://website-*.vercel.app`. Run:

        echo "$URL" | grep -qE "^https://${VERCEL_PROJECT}(-[a-z0-9]+)?\.vercel\.app$" && echo "PASS: project-named URL" || { echo "FAIL: URL '$URL' does not match project '$VERCEL_PROJECT' — Vercel link step likely failed. Re-run vercel project add + link before retrying deploy."; exit 1; }

If validation fails, re-extract from the deploy log. NEVER send a punycode URL to Slack, and NEVER accept a `website-*.vercel.app` URL — that means the project was misnamed.

**CRITICAL: From this point forward, ALWAYS read the URL from `.vercel-url` file — NEVER construct it from the project name, NEVER type it from memory.** Every Slack message or social post that includes the Vercel URL must first run: `cat $PROJECT_PATH/$PROJECT/.vercel-url`

**MANDATORY — Website checkpoint before proceeding:**
- [ ] Step 6a: docs/papers/*.html exist for all papers
- [ ] Step 6b: website/ builds without errors (`npm run build` succeeds)
- [ ] Step 6c: website/public/og/*.png exist for all papers
- [ ] Step 6d: Codex website review completed, issues fixed
- [ ] Step 6e: Vercel deployment succeeded, $VERCEL_URL captured, and URL subdomain matches `$VERCEL_PROJECT` (never `website-*`)

**MANDATORY — Slack notification with Vercel URL** using `mcp__claude_ai_Slack__slack_send_message` to `$SLACK_CHANNEL`.

Before composing the message, read the URL from disk:

    cat $PROJECT_PATH/$PROJECT/.vercel-url

Use ONLY the value read from that file. Do NOT type a URL from memory or construct one from the project name.

```
**Website deployed**

**Website:** [HOST](URL)   (URL = value from .vercel-url; HOST = URL without https://)
**Papers:** [count] HTML pages
**OG images:** [count]
**Codex review:** [issues found] → [issues fixed]
```

Substitute the literal URL as a markdown link on its own bold-label line — e.g. `**Website:** [ferrous-bridge.vercel.app](https://ferrous-bridge.vercel.app)`. The markdown form is REQUIRED: the MCP tool takes standard markdown, `<https://...>` renders literally, and a bare URL lets Slack's auto-linker consume adjacent characters from the next line/marker into the URL.

**MANDATORY — run `slack_lint_msg` on the composed message before sending.** Compose the message into a `$DEPLOY_MSG` variable, run `slack_lint_msg "$DEPLOY_MSG" || exit 1`, then send. The linter blocks bare URLs, angle-bracket URLs, and unbalanced `**` markers — same gate used for the final summary.

---

## Phase 7 — Social Posts

**Skip if `$SKIP_SOCIAL` is true.**

Spawn `social-posts` agent (foreground):

**Agent prompt:**
```
Generate social media posts for each research paper in the project.

Project root: $PROJECT_PATH/$PROJECT
Papers: [list all topics + synthesis with titles]
GitHub URL: https://github.com/$GITHUB_ORG/$PROJECT

IMPORTANT: Read the Vercel URL from disk by running: cat $PROJECT_PATH/$PROJECT/.vercel-url
Use ONLY the value from that file in all posts. NEVER guess or construct the URL from the project name — Vercel assigns its own subdomain.

For EACH paper, generate posts for 4 platforms. Save each to posts/$PLATFORM/$TOPIC.md

### Twitter/X (posts/twitter/$TOPIC.md)
- 280 character limit per tweet
- Hook-first: lead with the most surprising insight
- Thread format if needed (tweet 1/N)
- Include link to Vercel paper page
- 3-5 relevant hashtags
- Academic but accessible tone

### LinkedIn (posts/linkedin/$TOPIC.md)
- Professional, structured paragraphs
- Lead with problem statement
- 3-4 paragraphs: problem, approach, key finding, implications
- Include paper link and GitHub link
- Relevant hashtags at end

### Facebook (posts/facebook/$TOPIC.md)
- PLAIN TEXT ONLY — no markdown, no **bold**, no *italic*, no # headers
- Use emojis for visual structure
- Use line breaks (blank lines) to separate sections
- Use ALL CAPS sparingly for emphasis
- Structure: hook -> problem -> insight -> why it matters -> link -> hashtags
- Hashtags on their own line at the end
- Accessible to science-curious audience, not academic

### Bluesky (posts/bluesky/$TOPIC.md)
- 300 character limit
- Concise, punchy
- Link to paper
- 2-3 hashtags

Each post file should have YAML frontmatter with fields: platform, topic, title, status (draft).
```

---

## Phase 8 — Finalize

### Step 8a — Generate README.md (MANDATORY — do NOT skip)

Write `$PROJECT_PATH/$PROJECT/README.md` BEFORE committing or creating the GitHub repo. The README MUST exist before Step 8b.

Contents:
- Project title and description
- Architecture diagram (ASCII)
- Paper table (title, pages, category, links to Vercel pages and PDFs)
- Tech stack (LaTeX, Haskell, Next.js, Vercel)
- How to build locally
- Author info (from env vars)
- Links to Vercel site and individual papers
- Link to GitHub repo

Verify it exists: `test -f $PROJECT_PATH/$PROJECT/README.md && echo "OK" || echo "MISSING"`

### Step 8b — Git Commit and Push

**MANDATORY — Pre-commit verification.** Before committing, check that ALL generated artifacts are present and will be tracked:

    cd $PROJECT_PATH/$PROJECT
    # Remove any nested .gitignore that would exclude generated files
    find . -path ./.git -prune -o -name '.gitignore' -print
    # Check for untracked files that should be included
    git status -u

**MANDATORY — Verify PDFs are current (not stale from pre-fix compilation):**

    echo "=== PDF FRESHNESS CHECK ==="
    cd $PROJECT_PATH/$PROJECT
    for tex in papers/latex/*.tex; do
      name=$(basename "$tex" .tex)
      if test -f "papers/pdf/$name.pdf"; then
        if test "papers/pdf/$name.pdf" -nt "$tex"; then
          echo "PASS: $name.pdf is current"
        else
          echo "STALE: $name.pdf is older than $name.tex — RECOMPILING"
          cd papers/latex && pdflatex -interaction=nonstopmode "$name.tex" && pdflatex -interaction=nonstopmode "$name.tex" && cp "$name.pdf" ../pdf/ && cd $PROJECT_PATH/$PROJECT
        fi
      else
        echo "MISSING: $name.pdf — COMPILING"
        cd papers/latex && pdflatex -interaction=nonstopmode "$name.tex" && pdflatex -interaction=nonstopmode "$name.tex" && cp "$name.pdf" ../pdf/ && cd $PROJECT_PATH/$PROJECT
      fi
    done

Verify these directories have content:
- [ ] `papers/latex/*.tex` — LaTeX source files
- [ ] `papers/pdf/*.pdf` — compiled PDFs (verified current above)
- [ ] `reviews/*.md` — peer review output (round files + final canonical reviews)
- [ ] `src/*/` — Haskell source (if math present)
- [ ] `images/*.png` — cover images
- [ ] `docs/papers/*.html` — pandoc HTML conversions
- [ ] `website/` — full Next.js project (including package.json, package-lock.json, app/, public/, next.config.js)
- [ ] `website/public/og/*.png` — OG images
- [ ] `website/public/pdf/*.pdf` — PDF copies for download
- [ ] `website/public/images/*.png` — image copies
- [ ] `posts/` — social media posts (twitter/, linkedin/, facebook/, bluesky/)
- [ ] `README.md` — project README
- [ ] `.knowledge-base.md` — knowledge base

If website/.gitignore excludes node_modules/ that is correct. But if it excludes other generated files (like .next/ build output), that is also correct since the static export goes to out/. Do NOT delete website/.gitignore — it is needed. But DO ensure package-lock.json, README.md, and all source files under website/ are staged.

**MANDATORY — Sources licensing check.** arXiv preprints and other third-party source files must not ship in the repository. The Phase 1 `.gitignore` excludes `sources/*.pdf` and `sources/*.txt`; verify it is still in effect and that the README of links exists:

    cd $PROJECT_PATH/$PROJECT
    grep -qE '^sources/\*\.pdf' .gitignore && grep -qE '^\.review\.lock/' .gitignore && echo "GITIGNORE OK" || { echo "FAIL: .gitignore lost the sources/ or .review.lock/ rules — restore the Phase 1 block"; exit 1; }
    if [ -d sources ]; then
      test -s sources/README.md && grep -qE 'arxiv\.org/abs/|doi\.org/|https?://' sources/README.md && echo "SOURCES README OK" || { echo "FAIL: sources/README.md missing or has no links — list every source with its arXiv abstract/publisher link"; exit 1; }
      git ls-files --error-unmatch sources/*.pdf sources/*.txt >/dev/null 2>&1 && { echo "FAIL: source PDFs/TXT are tracked — git rm --cached them"; exit 1; } || echo "SOURCES NOT TRACKED OK"
    fi

Stage and commit ALL files. **Author MUST be `$RESEARCH_GIT_AUTHOR`** — re-verify the repo-local config is set before committing, in case this step runs in a fresh subshell:

    cd $PROJECT_PATH/$PROJECT
    # Re-resolve author in case this runs in a fresh subshell
    RESEARCH_GIT_AUTHOR="${RESEARCH_GIT_AUTHOR:-Matthew <mlong@magneton.io>}"
    git config user.name  "${RESEARCH_GIT_AUTHOR_NAME:-$(echo "$RESEARCH_GIT_AUTHOR" | sed -E 's/ *<[^>]+> *$//')}"
    git config user.email "${RESEARCH_GIT_AUTHOR_EMAIL:-$(echo "$RESEARCH_GIT_AUTHOR" | sed -nE 's/.*<([^>]+)>.*/\1/p')}"
    git add -A
    git status  # Verify everything is staged — no untracked files should remain
    git commit --author="$RESEARCH_GIT_AUTHOR" -m "Initial research pipeline output: [topic count] papers + synthesis

    Papers: [list topics]
    Includes: LaTeX sources, PDFs, Haskell proofs, HTML conversion, Next.js website, social posts"

    # Verify the commit's author is what we expect
    git log -1 --pretty=format:'%an <%ae>' | grep -qF "$RESEARCH_GIT_AUTHOR" && echo "AUTHOR OK" || { echo "FAIL: commit author is $(git log -1 --pretty=format:'%an <%ae>'), expected $RESEARCH_GIT_AUTHOR"; exit 1; }

**After committing, run `git status` again. If ANY untracked or unstaged files remain, stage and commit them in a follow-up commit. Zero files should be left behind.**

### Step 8c — Create GitHub Repo

First, read the Vercel URL from disk (do NOT guess it):

    VERCEL_URL=$(cat $PROJECT_PATH/$PROJECT/.vercel-url 2>/dev/null || echo "")

Then create the repo:

    gh repo create $GITHUB_ORG/$PROJECT --public \
      --description "Research papers: [brief description based on perspective and topics]" \
      --homepage "$VERCEL_URL"
    git remote add origin "https://github.com/$GITHUB_ORG/$PROJECT.git"
    git push -u origin main

### Step 8d — Final Slack Summary

**Before composing the message, read the Vercel URL from disk:**

    cat $PROJECT_PATH/$PROJECT/.vercel-url

Use ONLY the value from that file. NEVER construct, guess, or type the URL from memory.

#### Step 8d.1 — Compose the message text into a variable, then run BOTH gates

```bash
# Read URL from disk — never type it from memory.
VERCEL_URL=$(cat $PROJECT_PATH/$PROJECT/.vercel-url)

# Derive reviewer label from $RESEARCH_GEMINI_MODEL (see below).
GEMINI_LABEL=$(echo "${RESEARCH_GEMINI_MODEL:-gemini-3.1-pro}" \
  | sed -E 's/^gemini-/Gemini /' \
  | sed -E 's/-pro$/ Pro/; s/-flash$/ Flash/; s/-ultra$/ Ultra/')

# Compose the proposed message (standard markdown: **bold**, [label](url)).
VERCEL_HOST=${VERCEL_URL#https://}
SLACK_MSG=$(cat <<EOF
**Research Pipeline Complete**

**Project:** $PROJECT
**Topics:** [comma-separated list]
**Papers:** [count] research papers + 1 synthesis
**Haskell:** [compiled/skipped] ([module count] modules)
**Website:** [$VERCEL_HOST]($VERCEL_URL)
**GitHub:** [$GITHUB_ORG/$PROJECT](https://github.com/$GITHUB_ORG/$PROJECT)
**Social Posts:** [count] posts across 4 platforms

All papers peer-reviewed by $GEMINI_LABEL and format-checked by Codex.
EOF
)

# Gate 1 — inline linter (cheap, fast, mandatory).
slack_lint_msg "$SLACK_MSG" || { echo "FIX the message before sending"; exit 1; }
```

#### Step 8d.2 — Spawn `pipeline-validator` (HARD GATE before send)

Spawn the `pipeline-validator` agent (foreground, blocks the Slack send) with `mode: "bypassPermissions"`:

**Agent prompt:**
```
Validate the pipeline output before the final Slack notification is sent.

PROJECT_PATH: $PROJECT_PATH
PROJECT: $PROJECT
EXPECTED_VERCEL_URL: [value of $VERCEL_URL read from .vercel-url]

SLACK_MESSAGE (the EXACT text the orchestrator is about to send — validate verbatim, do not regenerate):
---
[paste the literal $SLACK_MSG content here, including every [label](url) markdown link]
---

Run all four check sections (OG images, Slack message URL safety, .vercel-url integrity, required artifacts) per your agent definition. Print PASS/FAIL per check and a final summary block. Exit non-zero on any FAIL.
```

If the validator returns FAIL:
- **OG images failed**: re-spawn `og-image-generator` and re-run the validator.
- **Slack message failed**: rewrite the message (most likely a URL is bare or angle-bracketed instead of `[label](url)`, or a `**` marker is unbalanced) and re-run both gates.
- **.vercel-url failed**: re-extract from /tmp/vercel-deploy.log or re-deploy.
- **Artifacts failed**: regenerate the missing file (PDF / HTML / OG image) before sending.

NEVER send the Slack message while the validator is in FAIL state. The whole point of the gate is mechanical enforcement.

#### Step 8d.3 — Send to `$SLACK_CHANNEL` via `mcp__claude_ai_Slack__slack_send_message`

Once **both** gates pass (`slack_lint_msg` returned 0 and `pipeline-validator` printed `OVERALL: PASS`), send the EXACT `$SLACK_MSG` text composed in Step 8d.1. Do NOT recompose the message between gating and sending — any post-validation edit invalidates the lint pass.

CRITICAL — the message text from Step 8d.1 already follows these rules; preserve them on send:
- Every URL is a markdown link `[label](https://...)` on its own bold-label line. The validator and linter both reject bare URLs and `<https://...>` forms — `https://github.com/YonedaAI/ferrous-bridge *Social` is a previously-shipped bug where Slack's auto-linker pulled the next `*` marker into the link, breaking BOTH the URL and the bold formatting, and `<https://...>` shipped once as literal angle brackets.
- The reviewer label is `$GEMINI_LABEL`, derived from `$RESEARCH_GEMINI_MODEL` at runtime. Never type "Gemini 2.5 Pro" or "Gemini 3.1 Pro" or any other literal version — it goes stale the moment the env var changes.

---

## Error Handling

- **Fix loops**: All review/fix cycles are bounded to **2 iterations maximum**. If issues persist after 2 rounds, log them and continue.
- **Missing tools**: The reviewer shim (`$GEMINI`) and `$CODEX` are MANDATORY — the Phase 1 sanity tests stop the pipeline if either is broken; read `${TMPDIR:-/tmp}/agy-review-shim.err` and never fall back to the deprecated `gemini` CLI. If `pdflatex` is not available, skip PDF compilation. If `vercel` is not available, skip deployment.
- **Empty reviewer output mid-run**: almost always a concurrent `agy`/`codex` call (mutex not held) or a stale `.review.lock` from a crashed worker. Check the lock directory, read the shim log, re-run the Step 1b sanity test, then respawn the affected worker.
- **Compilation failures**: If LaTeX or Haskell won't compile after 3 attempts, save the error log and continue with remaining topics.
- **Slack failures**: If Slack notification fails, log the error but don't block the pipeline.

## Agent Spawning Rules

- **Foreground agents** (need results before continuing): knowledge-base-builder, synthesis-agent, website-builder, **pipeline-validator** (final gate before Slack send)
- **Parallel agents** (independent work): research-workers (all topics), haskell-verifiers (all topics), og-image-generator
- **Background agents** (can overlap with other work): social-posts (if Vercel URL is already known)
- Always send parallel agents in a **single message with multiple Agent tool calls**
- **Parallel workers, serialized reviewers**: workers draft and fix in parallel, but every `"$GEMINI"` / `"$CODEX"` call across all agents holds the `$PROJECT_ROOT/.review.lock` mkdir mutex (Tool Resolution section). Concurrent reviewer calls return empty output. The orchestrator's own reviewer calls (Step 6d, Step 1d, Phase 4.5) hold the same lock.
- **Sub-agents have no Skill tool and no Agent tool**: never instruct a spawned agent to invoke `codex:rescue` or to spawn a subagent. Give them the direct `"$CODEX" exec` command and the BLOCKED-line fallback; the orchestrator runs `codex:rescue` (optional) and the external referee itself. Pass `PROJECT_ROOT`, `RESEARCH_CODEX_MODEL`, and `RESEARCH_CODEX_EFFORT` in every prompt.
- **MANDATORY — bypass permissions on every spawn**: Every Agent tool call in this pipeline MUST include `mode: "bypassPermissions"`. This is equivalent to `--dangerously-skip-permissions` and is required so sub-agents run their Bash/Write/Edit/WebFetch calls without stopping to prompt the user. The pipeline is long-running and unattended — a single prompt stalls the whole run. No exceptions: applies to knowledge-base-builder, research-worker (all topics), synthesis-agent, haskell-verifier, website-builder, og-image-generator, social-posts, **pipeline-validator**, and any codex:rescue / ad-hoc agent spawns.
