# research-agent settings — notes

The single source of reviewer configuration is `research-agent.settings.json` in this
directory. Prompts never hardcode reviewer model names; they read them from this file
(staged into the project root at run time).

**Core invariant: reviewers are never the main model drafting.**

## Fields

| Field | Meaning |
|---|---|
| `reviewers.science` | external science/paper reviewer: AGY, with auto-fallback model |
| `reviewers.code` | external code/format reviewer: Codex |
| `swapRules` | on host-model family collision, move that lane to `claude` |
| `noSelfReview` | `true` always — the drafting model may never review its own work |
| `entryFormat` | harness entry format (`skill-md`) |
| `installRoot` | per-harness install targets (self-contained copies; never `~/.agents/skills`) |

## Swap rules (host-model drafting)

The orchestrating host model IS the drafter (MiMo under MiMoCode, Claude under Claude
Code, GLM under opencode, the session model under Codex; `RESEARCH_DRAFTER_MODEL` names
it for swap decisions and reports). Reviewers stay external and disjoint:

- host family `gemini` → science lane swaps to Claude (AGY would share the drafter family)
- host family `openai` / `codex` → code lane swaps to Claude (Codex would review itself)
- anything else → defaults hold (AGY science, Codex code)

Family resolution chain: `RESEARCH_DRAFTER_MODEL` → host config (`~/.codex/config.toml`
model, `~/.config/opencode/opencode.jsonc` model) → unknown. Unknown family → AGY + Codex
(host-disjoint vendors) with `noSelfReview` enforced in every prompt. Never guess a
reviewer that could equal the drafter. There is deliberately no `drafter` field here: the
drafter is the executing host model, resolved at run time.

## Schema order matters

`reviewers.science` is listed before `reviewers.code`, so the first `"model"` key in the
JSON is the science model. The stage prompts resolve defaults with
`grep -m1 '"model"'` / `grep -m1 '"fallback"'` against this file; keep the order stable.
