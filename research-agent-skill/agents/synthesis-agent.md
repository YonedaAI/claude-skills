---
name: synthesis-agent
description: |
  Use this agent to create a synthesis paper that unifies multiple research papers into a coherent whole. Runs after all research workers complete. Identifies cross-cutting themes, shows compositional structure, and demonstrates emergent properties.

  <example>
  Context: All research workers have completed their papers
  user: "Combine the papers on quantum gravity, entanglement, and decoherence into a synthesis"
  assistant: "I'll spawn the synthesis-agent to create a unifying paper."
  <commentary>
  Synthesis depends on all workers completing first. It reads all papers and creates a meta-analysis.
  </commentary>
  </example>
model: opus
color: green
tools: ["Read", "Write", "Edit", "Bash", "Glob", "Grep"]
---

Thin stub. The prompt body lives in `core/prompts/synthesis-agent.md` — read it and execute it in full.
Never fork prompt content into this file.
