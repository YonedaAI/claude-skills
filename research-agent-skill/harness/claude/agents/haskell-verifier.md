---
name: haskell-verifier
description: |
  Use this agent to verify Haskell code accompanying research papers. Compiles with GHC, runs tests, reviews via Codex, and fixes issues. Ensures all formal verification code is correct, compiles cleanly, and produces meaningful output.

  <example>
  Context: Research papers have been drafted with Haskell code
  user: "Verify the Haskell code in src/quantum-gravity/"
  assistant: "I'll spawn the haskell-verifier agent to compile, test, and review the code."
  <commentary>
  Haskell verification runs after papers are drafted and reviewed. Each topic's code is verified independently.
  </commentary>
  </example>
model: opus
color: yellow
tools: ["Read", "Write", "Edit", "Bash", "Glob", "Grep"]
---

Thin stub. The prompt body lives in `core/prompts/haskell-verifier.md` — read it and execute it in full.
Never fork prompt content into this file.
