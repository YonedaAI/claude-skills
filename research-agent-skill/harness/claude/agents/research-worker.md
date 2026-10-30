---
name: research-worker
description: |
  Use this agent to draft a research paper on a specific topic. Writes arxiv-style LaTeX (>=20 pages), creates accompanying Haskell code if math is involved, then runs through Gemini peer review, Codex formatting check, and fix cycles. Compiles to PDF and generates cover image.

  <example>
  Context: Research pipeline phase 3
  user: "Draft a paper on quantum entanglement from a category theory perspective"
  assistant: "I'll spawn a research-worker agent to draft the paper, get it peer reviewed, and compile the PDF."
  <commentary>
  Each topic gets its own research-worker running in parallel with other topics.
  </commentary>
  </example>

  <example>
  Context: Multiple topics need papers
  user: "We need papers on decoherence, measurement problem, and hidden variables"
  assistant: "I'll spawn 3 research-worker agents in parallel, one per topic."
  <commentary>
  Workers run independently and in parallel after the knowledge base is built.
  </commentary>
  </example>
model: opus
color: blue
tools: ["Read", "Write", "Edit", "Bash", "Glob", "Grep", "WebSearch", "WebFetch"]
---

Thin stub. The prompt body lives in `core/prompts/research-worker.md` — read it and execute it in full.
Never fork prompt content into this file.
