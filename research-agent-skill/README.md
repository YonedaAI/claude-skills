# research-agent

A Claude Code plugin that orchestrates a multi-agent research pipeline. Takes comma-separated topics, spins up parallel research agents, and produces peer-reviewed papers with Haskell formal verification, a Vercel-deployed website, and social media posts.

## Usage

```
/research-agent "topic-a,topic-b,topic-c" --perspective "your framing"
```

### Options

| Flag | Description | Default |
|------|-------------|---------|
| `--perspective "..."` | Framing perspective for all papers | Inferred from project context |
| `--project <name>` | Project directory name | Derived from first topic |
| `--project-path <path>` | Where to create the project | Current working directory |
| `--github-org <org>` | GitHub organization | `YonedaAI` |
| `--no-haskell` | Skip Haskell formal verification | Enabled |
| `--no-website` | Skip website build + Vercel deploy | Enabled |
| `--no-social` | Skip social media posts | Enabled |
| `--slack-channel <ID>` | Slack channel for notifications | `$RESEARCH_SLACK_CHANNEL` or `C0AK269AVSA` |
| `--multi-agent-team` | Workers share interface contracts + a team board, integration gate before synthesis | Off |
| `--human-readable` | Humanizer writing rules + grep checks before final compile | Off |
| `--code-audit` | Codex read-only audit of the code evidence appendix (every row must be SUPPORTS) | Off |
| `--bib-gate` | Resolve every arXiv/DOI/URL bibliography entry before final compile | Off |
| `--plan-critique` | Codex critique of the plan before Phase 2 (max 3 rounds) | Off |
| `--codex-model <m>` | Model for direct `codex exec` calls (`RESEARCH_CODEX_MODEL`) | `gpt-5.6-sol` |
| `--codex-effort <e>` | Reasoning effort for `codex exec` (`RESEARCH_CODEX_EFFORT`) | `high` |

## Pipeline

```
Phase 1: Setup ──> Phase 2: Knowledge Base ──> Phase 3: Workers (parallel)
                                                  │
                              ┌───────────────────┼───────────────────┐
                              ▼                   ▼                   ▼
                         Topic A              Topic B              Topic N
                         Draft (20+ pages)    Draft (20+ pages)    Draft (20+ pages)
                         Gemini Peer Review   Gemini Peer Review   Gemini Peer Review
                         Claude Fix           Claude Fix           Claude Fix
                         Codex LaTeX Check    Codex LaTeX Check    Codex LaTeX Check
                         Claude Fix           Claude Fix           Claude Fix
                         Compile PDF          Compile PDF          Compile PDF
                         Cover Image          Cover Image          Cover Image
                         Slack ✓              Slack ✓              Slack ✓
                              │                   │                   │
                              └───────────────────┼───────────────────┘
                                                  ▼
Phase 4: Synthesis ──> Phase 5: Haskell Verify ──> Phase 6: Website + Vercel
                                                          │
                                                   Phase 7: Social Posts
                                                          │
                                                   Phase 8: Git + GitHub + Slack Summary
```

## Agents

| Agent | Model | Purpose |
|-------|-------|---------|
| `knowledge-base-builder` | Sonnet | Reads sources, builds structured knowledge base |
| `research-worker` | Opus | Drafts arxiv-style LaTeX papers + Haskell code |
| `synthesis-agent` | Opus | Unifies all papers into coherent synthesis |
| `haskell-verifier` | Opus | Compiles GHC, runs tests, fixes errors |
| `website-builder` | Sonnet | Builds Next.js 14 dark-themed research site |
| `og-image-generator` | Haiku | Generates 1200x630 OG images from covers |
| `social-posts` | Sonnet | Creates posts for Twitter/X, LinkedIn, Facebook, Bluesky |

## Review Pipeline

Every paper goes through two mandatory, externally-enforced review cycles:

1. **Gemini peer review** via the `agy-review-shim` (`$RESEARCH_GEMINI_BIN`; model label `$RESEARCH_GEMINI_MODEL`, default `gemini-3.1-pro`, routed to Antigravity's "Gemini 3.1 Pro (High)") — adversarial review by an external LLM (not self-review), saved to `reviews/`. Each worker MUST run the shim command and write the output to disk. Gate checks verify the review file exists and has substantive content. The plain `gemini` CLI is deprecated and is never used as a fallback; the shim's stderr log is `${TMPDIR:-/tmp}/agy-review-shim.err`.
2. **Codex formatting check** — LaTeX compilation, references, styling issues. Each worker MUST run the direct `codex exec -s read-only` command (sub-agents have no Skill tool, so `codex:rescue` is orchestrator-only).

All reviewer calls are serialized through a project-wide `.review.lock` mutex (concurrent `agy`/`codex` calls return empty output), and a 60-second sanity test of both reviewers runs in Phase 1 before any worker spawns.

Both cycles include fix iterations (max 2 per cycle). After all workers complete, the orchestrator runs a post-worker verification pass that checks every `reviews/$TOPIC-review.md` file exists with real content. Missing or stub reviews trigger a re-run. The website also gets a Codex review before Vercel deployment.

## Output Structure

```
project/
├── papers/latex/*.tex          # LaTeX sources with GrokRxiv sidebar
├── papers/pdf/*.pdf            # Compiled PDFs
├── reviews/*.md                # Gemini peer review feedback
├── src/*/                      # Haskell formal verification code
├── images/*.png                # Cover images (300 DPI)
├── docs/papers/*.html          # Pandoc HTML conversions
├── website/                    # Next.js 14 static site (deployed to Vercel)
│   └── public/og/*.png         # Open Graph images
├── posts/{twitter,linkedin,facebook,bluesky}/
│                               # Platform-specific social posts
├── .knowledge-base.md          # Structured knowledge base
└── README.md                   # Project overview
```

## Requirements

- Claude Code with plugins enabled
- `agy` (Antigravity) CLI plus the `agy-review-shim` wrapper at `$RESEARCH_GEMINI_BIN` (default `/Users/mlong/.local/bin/agy-review-shim`; the plain `gemini` CLI no longer works)
- `pdflatex` (LaTeX compilation)
- `pandoc` (LaTeX to HTML conversion)
- `ghc` / `cabal` / `stack` (Haskell verification)
- `vercel` CLI (website deployment)
- `pdftoppm` from poppler (cover image generation)
- Codex plugin (`codex@openai-codex`)
- Slack MCP (notifications)

## Installation

```bash
# Add the marketplace (one-time)
claude plugin marketplace add /path/to/claude-skills --scope user

# Install the plugin
claude plugin install research-agent@local-skills --scope user
```

## License

MIT — YonedaAI Research Collective
