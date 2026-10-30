# research-agent — one plugin, host-model drafting

A single research-pipeline plugin with a harness-agnostic core: parallel drafting agents
produce peer-reviewed arXiv-style papers with optional Haskell/Lean verification, a
deployed website, social posts, and Slack notifications. Adapters + settings only — no
forked content. The orchestrating host model IS the drafter (MiMo under MiMoCode, Claude
under Claude Code, GLM under opencode, the session model under Codex).

**Core invariant: reviewers are never the main model drafting.**

Science review = AGY (primary + fallback names in `settings/research-agent.settings.json`).
Code/format review = Codex. On family collision a lane swaps to Claude (host Gemini-family
→ science swaps; host OpenAI/GPT-family → code swaps). No lane ever equals the drafter.

## Architecture

```
research-agent-skill/
├── core/                       # the one shared copy — edited ONCE
│   ├── SKILL.body.md           # shared skill body (every entry stub points here)
│   ├── prompts/                # 9 role prompts (frontmatter-free stage procedures)
│   ├── references/             # 9 standards of record (incl. harness-matrix.md)
│   └── workflows/research-agent.js  # harness-agnostic 8-phase orchestration
├── harness/                    # thin entry stubs (≤30 lines) — never prompt bodies
│   ├── mimo/                   # SKILL.md + workflows link + slack/ app config
│   ├── opencode/               # SKILL.md (plain skill-md dir format)
│   ├── claude/                 # .claude-plugin/plugin.json, commands/, agents/
│   │                           # (frontmatter verbatim), skills/ entry
│   └── codex/                  # SKILL.md + CODEX.md overlay (authorship matrix:
│                               #   Codex authors; AGY science; Claude code;
│                               #   Codex NEVER reviews itself) + AGENTS.md snippet
├── settings/
│   ├── research-agent.settings.json   # reviewers + swap rules (no drafter field)
│   └── NOTES.md                       # config notes + the invariant
├── install.sh                  # detect | install | verify | uninstall | settings
└── README.md
```

Prompt bodies live only under `core/`, so harness copies can never drift apart again.

## Harness table

| Harness | Drafter | Science review | Code/format review | Install target | Gate |
|---|---|---|---|---|---|
| MiMoCode | session's MiMo model | AGY | Codex | `<project>/.mimocode/skills/research-agent/` + `~/.mimocode/skills/research-agent/` | runs now |
| Claude Code | session's Claude model | AGY | Codex | `~/.claude/plugins/` (cache + `installed_plugins.json` v2 entry) | `--ack-reviewed` |
| opencode | session's GLM model | AGY | Codex | `~/.config/opencode/skills/research-agent/` | `--ack-reviewed` |
| Codex | session's Codex model | AGY | **Claude** (Codex never reviews itself) | `~/.codex/skills/research-agent/` + CODEX.md overlay + AGENTS.md snippet | `--ack-reviewed` |

Detection (first match wins): `RESEARCH_HARNESS` env → `MIMOCODE=1`/`MIMOCODE_PID` →
`CLAUDECODE=1`/`CLAUDE_PLUGIN_ROOT` (never `CLAUDE_CODE_*` alone) → `CODEX_HOME` →
`~/.config/opencode/opencode.jsonc` exists → ambiguous: print evidence, stop and ask.
Full resolution + swap rules: `core/references/harness-matrix.md`.

Per-harness installs are self-contained copies. Never install into `~/.agents/skills`.

## Usage

```
/research-agent "topic-a, topic-b, topic-c" [--perspective "framing"] [flags]
```

Flags (parse per the Invocation table in `core/SKILL.body.md`): `--project`,
`--project-path`, `--github-org`, `--slack-channel`, `--no-haskell`, `--lean`,
`--no-website`, `--no-social`, `--human-readable`, `--code-audit`, `--bib-gate`,
`--plan-critique`.

## Install

```
./install.sh detect
./install.sh install mimo --project <dir>            # runs now
./install.sh install claude --ack-reviewed           # gated
./install.sh install all --ack-reviewed              # all four
./install.sh verify mimo --project <dir>
./install.sh uninstall mimo --project <dir>
./install.sh settings                                # resolved reviewers + swap rules
```

`--dry-run` prints the copy map and writes nothing. Installs are idempotent (second run
is a no-op). Claude installs mirror the `installed_plugins.json` v2
`research-agent@local-skills` entry shape (`scope` / `installPath` / `version`).
Manual fallback: copy `core/` + `settings/` + the harness stub into the target yourself.

## Pipeline

```
Phase 1: Setup → Phase 2: Knowledge Base → Phase 3: Workers (parallel)
→ Phase 4: Synthesis → Phase 5: Verify (Lean/Haskell) → Phase 6: Website
→ Phase 7: Social → Phase 8: Publish
```

Gates fail closed at every phase (reviewers answer PONG before any worker spawns; every
paper gets a real AGY review-fix loop and a real code/format review on disk; the PDF is
recompiled after all fixes). `core/references/` is the standards of record — when the
body and a reference disagree, the reference wins.
