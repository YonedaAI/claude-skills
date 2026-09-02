---
description: "Orchestrate a full multi-agent research pipeline. Takes comma-separated topics, spins up parallel research agents with Gemini peer review, Haskell verification, Vercel website, social posts, and Slack notifications."
argument-hint: "<topics> [--perspective '...'] [--project name] [--project-path /path] [--github-org org] [--no-haskell] [--no-website] [--no-social] [--slack-channel ID] [--multi-agent-team] [--human-readable] [--code-audit] [--bib-gate] [--plan-critique] [--codex-model m] [--codex-effort e]"
---

# Research Agent Pipeline

You have been invoked as `/research-agent`. Parse the user's input and orchestrate the full research pipeline.

## Input Parsing

The user provides: `/research-agent <topics> [flags]`

**Required:**
- `<topics>`: Comma-separated research topics (e.g. `"quantum-gravity,entanglement,decoherence"`)

**Optional flags:**
- `--perspective "..."`: Framing perspective for all papers (default: infer from project context or use "category theory")
- `--project <name>`: Project directory name (default: slugified from first topic)
- `--project-path <path>`: Absolute path to create project (default: current working directory)
- `--github-org <org>`: GitHub organization (default: "YonedaAI")
- `--no-haskell`: Skip Haskell formal verification. Sets `$SKIP_HASKELL` AND adds the line `Haskell is OFF: write no src/ directory` to every Phase 3 worker prompt — without that line workers still write Haskell.
- `--no-website`: Skip website build and Vercel deployment
- `--no-social`: Skip social media post generation
- `--slack-channel <ID>`: Slack channel ID for notifications (default: `$RESEARCH_SLACK_CHANNEL` env var, or `C0AK269AVSA`)
- `--multi-agent-team`: Workers exchange interface contracts in `team/<slug>/contract.md` before drafting, log to an append-only `team/board.md`, wait (bounded) for sibling drafts and reconcile cross-references, and an integration reviewer gate runs before synthesis (Phase 3). Protocol: `references/team-protocol.md`.
- `--human-readable`: Workers apply the humanizer rules (no em/en dashes, no `---` in prose, no AI vocabulary, sentence-case headings, straight quotes, no bold-header bullet lists, neutral scholarly voice) and the pipeline runs the grep checks in `references/team-protocol.md` before the final compile (Phase 3 prompt, Phase 4.5 checks).
- `--code-audit`: After the Codex formatting loop, a Codex read-only audit judges every row of the paper's code evidence appendix SUPPORTS / PARTIAL / NO; the gate passes only when every row is SUPPORTS (max 2 invocations, `reviews/<slug>-code-audit-round-N.md`, canonical `reviews/<slug>-code-audit.md`) (Phase 3, worker Stage 4b).
- `--bib-gate`: Every bibliography entry with an arXiv id, DOI or URL is resolved with WebFetch before the final compile; unresolved entries are removed or replaced; results in `team/<slug>/bib-check.md` (or `reviews/<slug>-bib-check.md` when there is no team dir) (Phase 4.5).
- `--plan-critique`: Before Phase 2 the orchestrator writes the plan to `PLAN.md` and runs a Codex read-only critique (VERDICT: PROCEED / REVISE), revising up to three rounds or until only non-blocking items remain (Phase 1, Step 1d).
- `--codex-model <m>`: Sets `RESEARCH_CODEX_MODEL` (default `gpt-5.6-sol`) for every direct `codex exec` call.
- `--codex-effort <e>`: Sets `RESEARCH_CODEX_EFFORT` (default `high`) for every direct `codex exec` call.

Export the parsed values as `$MULTI_AGENT_TEAM`, `$HUMAN_READABLE`, `$CODE_AUDIT`, `$BIB_GATE`, `$PLAN_CRITIQUE`, `$CODEX_MODEL`, `$CODEX_EFFORT` for the skill's Input Contract.

## Execution

After parsing input, follow the orchestration defined in the `research-agent` skill. The skill contains the full 8-phase pipeline:

1. **Setup** - Create project directory structure, git init
2. **Knowledge Base** - Spawn knowledge-base-builder agent to read sources
3. **Research Workers** - Spawn parallel research-worker agents (one per topic)
4. **Synthesis** - Spawn synthesis-agent to combine all topics
5. **Haskell Verification** - Spawn haskell-verifier agents (unless `--no-haskell`)
6. **Website** - Build Next.js site, deploy to Vercel (unless `--no-website`)
7. **Social Posts** - Generate multi-platform posts (unless `--no-social`)
8. **Finalize** - Git commit, create GitHub repo, push, Slack summary

Report progress to the user as each phase completes.
