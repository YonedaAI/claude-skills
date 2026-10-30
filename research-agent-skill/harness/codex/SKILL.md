---
name: research-agent
description: "Use when the user asks to research topics, generate research papers, run a research pipeline, create academic papers with peer review, or invokes /research-agent. Orchestrates parallel drafting agents with AGY (Gemini) scientific peer review, Codex formatting checks, optional Haskell/Lean verification, website deployment, social posts, and Slack notifications."
---

# research-agent (Codex adapter)

Thin entry stub. The single shared body lives at `core/SKILL.body.md` — read it and follow
it exactly. Content changes go in `core/` only; never fork prompt bodies into harness files.

Runtime adapter: when the research-agent skill runs inside Codex with native collaboration
tools (`spawn_agent`, `send_message`, `followup_task`, `wait_agent`, `interrupt_agent`),
read [CODEX.md](CODEX.md) completely before taking any pipeline action. Its Codex-specific
rules override conflicting instructions in the body about agent spawning, model selection,
review stages, and orchestration planning.

- Host: Codex. The host model drafts — Codex NEVER reviews itself
  (code lane swaps to Claude; science stays AGY).
- Workflow: `core/workflows/research-agent.js`. Detection + swap rules: `core/references/harness-matrix.md`.
