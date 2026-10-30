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
| `--no-haskell` | skip the Haskell taxonomy layer | enabled |
| `--lean` | run the Lean verification phase (`prompts/lean-verifier.md`) | off |
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
3. **Make the workflow discoverable** (only when the `workflow` tool is present): if
   `<project>/.mimocode/workflows/research-agent.js` is absent, copy this skill's
   `workflows/research-agent.js` there first — the tool only finds scripts at
   `.mimocode/workflows/<name>.js` (or `.claude/workflows/`) relative to the run workspace.
   The tool is registered only at process launch (`MIMOCODE_EXPERIMENTAL_WORKFLOW_TOOL=true`);
   if it is absent from the tool surface, do NOT try to enable it mid-session — use the
   subagent orchestration in step 4.
4. **Orchestrate with subagents (default path).** Spawn one `general` subagent per unit via the
   actor tool and hold the gate between phases. Sequence (mirrors `workflows/research-agent.js`):
   1. Setup — dirs, local-author git config, `.gitignore`, and AGY+Codex PONG tests. Hard gate:
      no worker spawns until BOTH reviewers answer PONG (run the PONG probe with
      `AGY_REVIEW_MIN_CHARS=1`; the shim's 500-char floor rejects a genuine PONG).
   2. Knowledge base — one agent writes `.knowledge-base.md` from `sources/`.
   3. Workers — one agent per topic in parallel, each executing `prompts/research-worker.md`
      in full. Gate: every worker reports `status:"ok"` with `reviewRounds >= 1`.
   4. Synthesis — one agent executes `prompts/synthesis-agent.md`; same review gate.
   5. Verification per args flags — Lean (`prompts/lean-verifier.md`: scaffold → one module
      per topic in parallel → assembler with the single consolidated Codex review) and/or
      Haskell (`prompts/haskell-verifier.md`).
   6. Website — `prompts/website-builder.md` (includes Vercel deploy).
   7. Social — `prompts/social-posts.md`.
   8. Publish — `prompts/pipeline-validator.md`: validator → README → git/PR → Slack summary.
   Gates are fail-closed: on failure, fix and re-run only the failed unit. A missing or
   malformed report means that unit failed. Never report success on a partial run.
5. **Alternative: run the workflow** with the `workflow` tool when it IS available:
   `{"operation": {"action": "run", "name": "research-agent", "args": <the JSON>, "workspace": "<project dir>"}}`
   Never pass both `name` and `script`. `ok: false` means a gate failed — the `reason` names
   it. A `null` agent result means the run did not complete.

### `args` shape

```json
{
  "topics": ["...", "..."],
  "perspective": "...",
  "project": "kebab-case-name",
  "githubOrg": "YonedaAI",
  "slackChannel": "C0AK269AVSA",
  "noHaskell": false,
  "lean": false,
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
siblings and must be run verbatim.

**Codex is resolved at runtime, never pinned.** The standalone install tracks the installed
version via `~/.codex/packages/standalone/current`, so `command -v codex` follows upgrades.
The resolver deliberately skips `fnm` node-version installs: those pin a stale npm release
(observed: 0.145.0 while standalone was 0.165.0), fail to parse the models cache
(`missing field 'base_instructions'`), and then reject models the installed CLI supports.

| Var | Default | Notes |
|---|---|---|
| `RESEARCH_GEMINI_BIN` | `/Users/mlong/.local/bin/agy-review-shim` | the only AGY path |
| `RESEARCH_GEMINI_MODEL` | `gemini-3.8-flash-medium` | label written into review files |
| `AGY_REVIEW_MODEL` | `Gemini 3.8 Flash (Medium)` | **what agy actually runs** — effort is in the name; the shim ignores the caller's `-m`. Quota-aware: Argon draws a separate weekly bucket (~13% left 2026-10-29), Flash shares the large Gemini bucket |
| `AGY_REVIEW_FALLBACK_MODEL` | `Gemini 4 Argon (High)` | auto-switch target when the primary model fails (quota/interruption) |
| `AGY_REVIEW_EFFORT` | *(leave unset)* | `agy` 1.1.23+ rejects `--effort` on effort-bearing names |
| `RESEARCH_CODEX_BIN` | *(unset — resolved at runtime)* | optional override; otherwise `command -v codex`, skipping fnm paths |
| `RESEARCH_CODEX_MODEL` | `gpt-6.1-sol` | formatting/code reviewer |
| `RESEARCH_CODEX_EFFORT` | `medium` | mechanical lint — high buys little here |

- The plain `gemini` CLI is **deprecated** and exits immediately. Never fall back to it.
- Every reviewer call holds the project-wide `.review.lock` mutex — one call per lock hold.
- Review rounds: AGY max **3**, Codex max **2** fix passes. Reviews run in parallel lanes — 3 AGY (`.review.slot.1..3`) + 3 Codex (`.codex.slot.1..3`), independent backends; never remove a lane you don't own.
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

Slack is a **local** MCP server named `slack` in `~/.config/mimocode/mimocode.jsonc`
(`@modelcontextprotocol/server-slack`, bot-token auth, team `TAYUPH83U`). It is MiMoCode-owned —
never read or write `~/.claude.json` for this.

**The bot is a dedicated app: "Research Agent"** (`user: research_agent`, `B0CDC1197B4`). Do not
fall back to the AgentHero token — that one posts as "AgentHero Notifications" because it lacks
`chat:write.customize`. Credentials live at `~/.config/research-agent/slack.env.json` (mode 0600),
outside every git repo. The app display name carries the identity, so **no per-message
`username` override is needed**; `chat:write.customize` is there if a custom icon or label is
ever wanted.

The send tool is **`mcp__slack__slack_post_message`** (arg `channel_id`, then `text`). Other
tools on that server: `slack_list_channels`, `slack_reply_to_thread`, `slack_add_reaction`,
`slack_get_channel_history`, `slack_get_thread_replies`, `slack_get_users`,
`slack_get_user_profile`.

`slack_lint_msg` and the markdown rules above survive any tool rename. Notifications fire at
five points minimum: worker complete, synthesis, Haskell, website deploy, final summary.

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
