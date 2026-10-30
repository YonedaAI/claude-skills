---
name: research-agent
description: "Use when the user asks to research topics, generate research papers, run a research pipeline, create academic papers with peer review, or invokes /research-agent. Orchestrates parallel drafting agents with AGY (Gemini) scientific peer review, Codex formatting checks, optional Haskell/Lean verification, website deployment, social posts, and Slack notifications."
---

# research-agent (Claude Code adapter)

Thin entry stub. The single shared body lives at `core/SKILL.body.md` — read it and follow
it exactly. Content changes go in `core/` only; never fork prompt bodies into harness files.

- Host: Claude Code. The host model (Claude) drafts — reviewers are never the main model drafting.
- Reviewers: AGY science, Codex code/format (names in `settings/research-agent.settings.json`).
- Workflow: `core/workflows/research-agent.js` (copy to `.claude/workflows/` when the workflow tool is present).
- Detection + swap rules: `core/references/harness-matrix.md`.
