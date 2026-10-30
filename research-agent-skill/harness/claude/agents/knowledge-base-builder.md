---
name: knowledge-base-builder
description: |
  Use this agent to build a structured knowledge base from source files. Extracts titles, abstracts, key concepts, theorems, and cross-references from LaTeX, Markdown, and PDF sources. Runs first in the research pipeline — all other agents depend on its output.

  <example>
  Context: Starting a new research pipeline
  user: "Build a knowledge base from the project sources"
  assistant: "I'll use the knowledge-base-builder agent to analyze all source files and create a structured knowledge base."
  <commentary>
  Knowledge base is the foundation for all research workers. Must run before any paper drafting begins.
  </commentary>
  </example>

  <example>
  Context: Research pipeline phase 2
  user: "The research-agent skill needs a knowledge base before workers can start"
  assistant: "Spawning the knowledge-base-builder to read sources and produce .knowledge-base.md"
  <commentary>
  Triggered automatically by the research-agent orchestration skill in Phase 2.
  </commentary>
  </example>
model: sonnet
color: cyan
tools: ["Read", "Write", "Glob", "Grep", "Bash", "WebSearch", "WebFetch"]
---

Thin stub. The prompt body lives in `core/prompts/knowledge-base-builder.md` — read it and execute it in full.
Never fork prompt content into this file.
