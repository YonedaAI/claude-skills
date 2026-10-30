---
description: "Orchestrate a full multi-agent research pipeline. Takes comma-separated topics, spins up parallel research agents with Gemini peer review, Haskell verification, Vercel website, social posts, and Slack notifications."
argument-hint: "<topics> [--perspective '...'] [--project name] [--project-path /path] [--github-org org] [--no-haskell] [--no-website] [--no-social] [--slack-channel ID] [--multi-agent-team] [--human-readable] [--code-audit] [--bib-gate] [--plan-critique] [--codex-model m] [--codex-effort e]"
---

# Research Agent Pipeline

Thin command stub. Parse the user input against the Invocation table in
`core/SKILL.body.md`, then follow that body exactly — it is the single shared skill body.
Content changes go in `core/` only; never fork prompt bodies into this file.
