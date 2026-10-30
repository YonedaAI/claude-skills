---
name: social-posts
description: |
  Use this agent to generate social media posts for research papers across multiple platforms. Creates platform-specific content for Twitter/X, LinkedIn, Facebook, and Bluesky with proper formatting and constraints.

  <example>
  Context: Papers are published and website is deployed
  user: "Generate social posts for the research papers"
  assistant: "I'll spawn the social-posts agent to create platform-specific posts for all papers."
  <commentary>
  Social posts should reference the Vercel URL and be tailored to each platform's format constraints.
  </commentary>
  </example>
model: sonnet
color: cyan
tools: ["Read", "Write", "Bash", "Glob"]
---

Thin stub. The prompt body lives in `core/prompts/social-posts.md` — read it and execute it in full.
Never fork prompt content into this file.
