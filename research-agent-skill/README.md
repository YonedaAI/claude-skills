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

Every paper goes through two mandatory review cycles:

1. **Gemini 3.1 Pro peer review** via CLI — adversarial review (not self-review), saved to `reviews/`
2. **Codex formatting check** — LaTeX compilation, references, styling issues

Both cycles include fix iterations (max 2 per cycle). The website also gets a Codex review before Vercel deployment.

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
- `gemini` CLI (Gemini 3.1 Pro peer review)
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
