---
name: research-agent
description: "Use when the user asks to research topics, generate research papers, run a research pipeline, create academic papers with peer review, or invokes /research-agent. Orchestrates parallel MiMo drafting agents with AGY (Gemini) scientific peer review, Codex formatting checks, optional Haskell verification, website deployment, multi-platform social posts, and Slack notifications."
---

# research-agent — MiMoCode skill

MiMo drafts. AGY and Codex review. A Dynamic Workflow sequences eight phases and fails
closed at every gate. This skill is the entry point; the orchestration lives in
`workflows/research-agent.js` and the stage procedures in `prompts/`.

## What this is NOT

- **Not Claude Code.** No `Agent` tool, no `mode: "bypassPermissions"`, no
  `${CLAUDE_PLUGIN_ROOT}`, no `codex:rescue` skill. Do not invoke any of those.
- **Not a Claude-model pipeline.** Nothing here drafts on `opus`/`sonnet`/`haiku`. If you see
  those names in output, something is wrong.
- **Not self-reviewing.** MiMo authors every artifact. The author may never review its own
  work — that is a pipeline failure, not a shortcut.

## Invocation

```
/research-agent "topic-a, topic-b, topic-c" [options]
```

| Option | Meaning | Default |
|---|---|---|
| `--perspective "..."` | framing for all papers | inferred from project context |
| `--project <name>` | project directory name | derived from first topic |
| `--project-path <path>` | where to create the project | current working directory |
| `--github-org <org>` | GitHub org for the PR | `YonedaAI` |
| `--slack-channel <ID>` | Slack channel for notifications | `$RESEARCH_SLACK_CHANNEL` or `C0AK269AVSA` |
| `--no-haskell` | skip Haskell/Lean verification | enabled |
| `--no-website` | skip website build + deploy | enabled |
| `--no-social` | skip social posts | enabled |
| `--human-readable` | humanizer grep gate before compile | off |
| `--code-audit` | audit the code evidence appendix | off |
| `--bib-gate` | resolve every bibliography entry first | off |
| `--plan-critique` | critique the plan before Phase 2 | off |

## Run procedure — do these in order

1. **Parse** the request into the `args` JSON shape below.
2. **Stage the workspace.** The pipeline writes into a project directory. Copy the skill's
   `prompts/` and `references/` directories into that project root so the subagents can read
   them at `prompts/*.md` and `references/*.md`. If they are not present, every agent will
   fail on the first line of its procedure.
3. **Make the workflow discoverable.** The `workflow` tool only finds scripts at
   `.mimocode/workflows/<name>.js` (or `.claude/workflows/`) relative to the run workspace.
   If `<project>/.mimocode/workflows/research-agent.js` is absent, copy this skill's
   `workflows/research-agent.js` there first. A global install alone is not enough.
4. **Run the workflow** with the `workflow` tool:
   `{"operation": {"action": "run", "name": "research-agent", "args": <the JSON>, "workspace": "<project dir>"}}`
   Never pass both `name` and `script`.
5. **Inspect the result.** `ok: false` means a gate failed — the `reason` names it. Do not
   report success on a partial run. `agent()` resolves `null` on failure; the workflow already
   treats that as a gate failure, so a `null` anywhere means the run did not complete.

### `args` shape

```json
{
  "topics": ["...", "..."],
  "perspective": "...",
  "project": "kebab-case-name",
  "githubOrg": "YonedaAI",
  "slackChannel": "C0AK269AVSA",
  "noHaskell": false,
  "noWebsite": false,
  "noSocial": false,
  "humanReadable": false,
  "codeAudit": false,
  "bibGate": false,
  "planCritique": false
}
```

## Models — measured, not assumed

Your MiMo plan serves exactly two chat models (verified against
`https://token-plan-sgp.xiaomimimo.com/v1`):

| Model | Use for |
|---|---|
| `xiaomi/mimo-v2.6-pro` | paper drafting, synthesis, math, Haskell/Lean |
| `xiaomi/mimo-v2.6-flash` | knowledge base, website, social, validation, OG images |

**`mimo-v2.6-pro-ultraspeed` is NOT on this plan** and returns `400 Not supported model`.
Do not reference it anywhere.

## Reviewers — preserve exactly

These are external CLIs. The resolver blocks live in `prompts/research-worker.md` and its
siblings and must be run verbatim (Node is managed by `fnm`, so bare `gemini`/`codex` fail in
non-interactive subshells — that is why the absolute-path resolver exists).

| Var | Default | Notes |
|---|---|---|
| `RESEARCH_GEMINI_BIN` | `/Users/mlong/.local/bin/agy-review-shim` | the only AGY path |
| `RESEARCH_GEMINI_MODEL` | `gemini-4-argon` | label "Gemini 4 Argon (High)" |
| `AGY_REVIEW_EFFORT` | *(leave unset)* | `agy` 1.1.23+ rejects `--effort` on effort-bearing names |
| `RESEARCH_CODEX_BIN` | `…/fnm/node-versions/v24.14.0/installation/bin/codex` | absolute path |
| `RESEARCH_CODEX_MODEL` | `gpt-5.6-sol` | |
| `RESEARCH_CODEX_EFFORT` | `high` | |

- The plain `gemini` CLI is **deprecated** and exits immediately. Never fall back to it.
- Every reviewer call holds the project-wide `.review.lock` mutex — one call per lock hold.
- Review rounds: AGY max **3**, Codex max **2** fix passes.
- Review files: `reviews/<topic>-review-round-N.md` (AGY) and `*-codex-review*` (Codex).
  A `SKIPPED` stub, a header-only file, or a round-1-only non-publishable verdict is a
  **pipeline failure**, not a pass.

## Hard gates

1. AGY and Codex must both answer a `PONG` sanity test **before any worker spawns**.
2. Every paper gets a real AGY review-fix loop with at least one round on disk.
3. Every paper gets a real Codex formatting check with at least one round on disk.
4. The PDF must be recompiled after all fixes so it matches the final `.tex`.
5. Geometry is `\usepackage[margin=1in]{geometry}` — one-inch margins. Never 12pt. Never
   override the geometry. The format check in `references/paper-format.md` is authoritative.
6. No agent activity, reviewer verdicts, confidence labels, or process language in any paper.
7. Every Slack message passes `slack_lint_msg` first: standard markdown `[label](url)` and
   `**bold**`. The angle-bracket `<https://…>` form is **wrong** and a bare URL is a lint failure.

## Slack

Slack is an MCP server named `slack` (see `~/.config/mimocode/mimocode.jsonc`). Discover the
real tool name after it connects and use `mcp__slack__<tool>`. `slack_lint_msg` and the
markdown rules above survive any tool rename. Notifications fire at five points minimum:
worker complete, synthesis, Haskell, website deploy, final summary.

## Layout

```
research-agent-skill/
├── skills/research-agent/SKILL.md   # this file
├── workflows/research-agent.js      # the 8-phase Dynamic Workflow
├── prompts/*.md                     # stage procedures (frontmatter-free)
└── references/*.md                  # writing + format standards (authoritative)
```

The `references/` documents are the standards of record. When this skill and a reference
disagree, the reference wins.
