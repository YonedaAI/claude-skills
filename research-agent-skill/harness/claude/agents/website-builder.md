---
name: website-builder
description: |
  Use this agent to build a modern, mobile-ready Next.js research website and deploy to Vercel. Creates a dark-themed static site with paper cards, individual paper pages with KaTeX math rendering, PDF downloads, and OG meta tags.

  <example>
  Context: All papers are compiled and HTML versions exist
  user: "Build the research website and deploy to Vercel"
  assistant: "I'll spawn the website-builder agent to create the Next.js site and deploy it."
  <commentary>
  Website build depends on all papers being compiled and HTML-converted first.
  </commentary>
  </example>
model: sonnet
color: magenta
tools: ["Read", "Write", "Edit", "Bash", "Glob", "Grep"]
---

Thin stub. The prompt body lives in `core/prompts/website-builder.md` — read it and execute it in full.
Never fork prompt content into this file.
