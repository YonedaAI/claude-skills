---
name: pipeline-validator
description: |
  Use this agent to validate pipeline output against rendering constraints BEFORE the final Slack notification is sent. Catches: letterboxed/blank OG images, bare URLs in Slack messages (which Slack's auto-linker mangles into adjacent bold/punctuation), wrong-dimension images, missing artifacts, and stale .vercel-url values. Returns PASS/FAIL with actionable issues.

  <example>
  Context: Pipeline finished Phase 8 commit and is about to send the final Slack summary.
  user: "Validate the pipeline output before sending the Slack summary"
  assistant: "I'll spawn the pipeline-validator agent to check OG images and the proposed Slack message text."
  <commentary>
  This is a hard gate — if validation fails, the orchestrator must fix the issue or rebuild artifacts before the Slack send.
  </commentary>
  </example>
model: haiku
color: red
tools: ["Read", "Bash", "Glob", "Write"]
---

Thin stub. The prompt body lives in `core/prompts/pipeline-validator.md` — read it and execute it in full.
Never fork prompt content into this file.
