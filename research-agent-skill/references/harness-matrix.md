# Harness matrix — auto-detect the harness, switch the main drafter

The research-agent runs under three harnesses, one branch per harness (`claude`, `mimo`,
`codex`). Detect the runtime at setup, then set the drafting models for that harness.
One rule never changes: **the drafter never reviews its own work.**

## Detection (first match wins)

| Order | Harness | Marker |
|---|---|---|
| 1 | explicit override | `RESEARCH_HARNESS` env = `claude` / `mimo` / `codex` |
| 2 | Claude Code | `$CLAUDE_PLUGIN_ROOT` or `$CLAUDECODE` set |
| 3 | MiMoCode | `$MIMOCODE_HOME` or `$MIMOCODE_CLIENT` set (fallback: `mimo` on PATH and a `.mimocode/` dir in the project) |
| 4 | Codex | `$CODEX_HOME` or `$CODEX_SANDBOX` set (fallback: running under `codex exec`) |
| 5 | ambiguous | stop and ask — never guess the harness |

Record the detected harness in the setup report JSON (`"harness":"claude|mimo|codex"`).

## Drafter matrix

| Harness | Main drafter (papers / synthesis / math / Lean) | Secondary drafter (website / social / KB) | Science review | Format + code review |
|---|---|---|---|---|
| claude | the session's Claude model (opus-class; `RESEARCH_DRAFTER` overrides) | sonnet-class | AGY (`Gemini 3.8 Flash (Medium)`, fallback `Gemini 4 Argon (High)`) | Codex (`gpt-6.1-sol`) |
| mimo | `xiaomi/mimo-v2.6-pro` | `xiaomi/mimo-v2.6-flash` | AGY | Codex |
| codex | the session's Codex model | same | AGY | Claude code review — **never** Codex on its own work |

Independence rule: if the drafter and a reviewer would be the same model family, move that
review to the other vendor. AGY and Codex defaults above are the shared baseline; only the
drafter column switches per harness.

## Per-harness installs (never one shared global)

| Harness | Install location | Branch |
|---|---|---|
| MiMoCode | `.mimocode/skills/research-agent/` (per project) and `~/.mimocode/skills/research-agent/` (user) | `mimo` |
| Claude Code | `claude plugin install` from this repo's `claude` branch | `claude` |
| Codex | its own install from the `codex` branch | `codex` |

Do not install into `~/.agents/skills/` as a cross-harness global: each harness must get its
own copy so the drafter default and file format (frontmatter or not) stay correct for it.
