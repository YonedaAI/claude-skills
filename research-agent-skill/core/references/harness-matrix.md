# Harness matrix — the host model drafts, reviewers stay external

One plugin, harness-agnostic core. Adapters (`harness/*`) and settings only — no forked
content. The orchestrating host model IS the drafter: GLM from opencode drafts with GLM;
Claude with Claude; MiMo with MiMo; the session's Codex model with Codex.
`RESEARCH_DRAFTER_MODEL` overrides for special cases.

**Core invariant: reviewers are never the main model drafting.**

- science review = AGY (primary + fallback model names in
  `settings/research-agent.settings.json` → `reviewers.science`)
- code/format review = Codex (`reviewers.code`)
- swap on family collision (below)

Never guess a reviewer that could equal the drafter. `noSelfReview: true` is enforced in
every prompt.

## Detection (first match wins; see `install.sh detect`)

| Order | Harness | Marker |
|---|---|---|
| 1 | override | `RESEARCH_HARNESS` env = `mimo` / `claude` / `codex` / `opencode` |
| 2 | MiMoCode | `MIMOCODE=1` / `MIMOCODE_PID` |
| 3 | Claude Code | `CLAUDECODE=1` / `CLAUDE_PLUGIN_ROOT` (never `CLAUDE_CODE_*` alone) |
| 4 | Codex | `CODEX_HOME` |
| 5 | opencode | `~/.config/opencode/opencode.jsonc` exists (no env marker exists) |
| 6 | ambiguous | print evidence, stop and ask — never guess the harness |

## Drafter + reviewer resolution

| Harness | Drafter | Science review | Code/format review |
|---|---|---|---|
| mimo | the session's MiMo model (`xiaomi/mimo-v2.6-pro` for papers) | AGY | Codex |
| claude | the session's Claude model | AGY | Codex |
| opencode | the session's GLM model | AGY | Codex |
| codex | the session's Codex model | AGY | **Claude** (host is OpenAI/GPT-family — Codex never reviews itself) |
| unknown family | the host model | AGY | Codex |

`RESEARCH_DRAFTER_MODEL` names the drafter for swap decisions and reports (the host
model writes regardless — no lookup is needed to write). Family chain: env → host config
(`~/.codex/config.toml` model; `~/.config/opencode/opencode.jsonc` model) → unknown
(claude/mimo expose no model key). Unknown family → AGY + Codex (host-disjoint vendors)
+ `noSelfReview: true` enforced in every prompt.

## Swap rules (family collision)

| Host family | Lane | Reviewer swaps to |
|---|---|---|
| `gemini` | science | Claude (AGY shares the drafter family) |
| `openai`, `codex` | code | Claude (Codex would review itself) |
| anything else | both | unchanged (AGY science, Codex code) |

No lane ever equals the drafter. Defaults live in `settings/research-agent.settings.json`
(`swapRules`); this table is the human-readable mirror — keep them in sync.

## Per-harness installs (self-contained copies, never one shared global)

| Harness | Install location | Gate |
|---|---|---|
| MiMoCode | `<project>/.mimocode/skills/research-agent/` + `~/.mimocode/skills/research-agent/` | runs now |
| opencode | `~/.config/opencode/skills/research-agent/` | `--ack-reviewed` |
| Claude Code | `~/.claude/plugins/` (plugin cache + `installed_plugins.json` v2 entry) | `--ack-reviewed` |
| Codex | `~/.codex/skills/research-agent/` (+ CODEX.md overlay, AGENTS.md snippet) | `--ack-reviewed` |

Do not install into `~/.agents/skills/` as a cross-harness global: each harness must get
its own self-contained copy so the entry format (frontmatter or not) stays correct for it.
Entry stubs stay thin (≤30 lines) and point at `core/SKILL.body.md`; prompt bodies live
only under `core/`, so bodies can never drift apart again.
