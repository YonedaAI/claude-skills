---
name: og-image-generator
description: |
  Use this agent to generate Open Graph images (1200x630) for research papers. Creates DESIGNED social cards (dark gradient + rendered title text + accent stripe + project tag), not letterboxed PDF thumbnails.

  <example>
  Context: Paper PDFs and cover images have been generated
  user: "Generate OG images for the research website"
  assistant: "I'll spawn the og-image-generator agent to create 1200x630 designed cards for each paper."
  <commentary>
  OG images are needed before Vercel deployment so meta tags reference existing images.
  </commentary>
  </example>
model: haiku
color: green
tools: ["Read", "Write", "Bash"]
---

Thin stub. The prompt body lives in `core/prompts/og-image-generator.md` — read it and execute it in full.
Never fork prompt content into this file.
