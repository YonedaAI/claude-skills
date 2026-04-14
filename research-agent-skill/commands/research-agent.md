---
description: "Orchestrate a full multi-agent research pipeline. Takes comma-separated topics, spins up parallel research agents with Gemini peer review, Haskell verification, Vercel website, social posts, and Slack notifications."
argument-hint: "<topics> [--perspective '...'] [--project name] [--project-path /path] [--github-org org] [--no-haskell] [--no-website] [--no-social] [--slack-channel ID]"
---

# Research Agent Pipeline

You have been invoked as `/research-agent`. Parse the user's input and orchestrate the full research pipeline.

## Input Parsing

The user provides: `/research-agent <topics> [flags]`

**Required:**
- `<topics>`: Comma-separated research topics (e.g. `"quantum-gravity,entanglement,decoherence"`)

**Optional flags:**
- `--perspective "..."`: Framing perspective for all papers (default: infer from project context or use "category theory")
- `--project <name>`: Project directory name (default: slugified from first topic)
- `--project-path <path>`: Absolute path to create project (default: current working directory)
- `--github-org <org>`: GitHub organization (default: "YonedaAI")
- `--no-haskell`: Skip Haskell formal verification
- `--no-website`: Skip website build and Vercel deployment
- `--no-social`: Skip social media post generation
- `--slack-channel <ID>`: Slack channel ID for notifications (default: `$RESEARCH_SLACK_CHANNEL` env var, or `C0AK269AVSA`)

## Execution

After parsing input, follow the orchestration defined in the `research-agent` skill. The skill contains the full 8-phase pipeline:

1. **Setup** - Create project directory structure, git init
2. **Knowledge Base** - Spawn knowledge-base-builder agent to read sources
3. **Research Workers** - Spawn parallel research-worker agents (one per topic)
4. **Synthesis** - Spawn synthesis-agent to combine all topics
5. **Haskell Verification** - Spawn haskell-verifier agents (unless `--no-haskell`)
6. **Website** - Build Next.js site, deploy to Vercel (unless `--no-website`)
7. **Social Posts** - Generate multi-platform posts (unless `--no-social`)
8. **Finalize** - Git commit, create GitHub repo, push, Slack summary

Report progress to the user as each phase completes.
