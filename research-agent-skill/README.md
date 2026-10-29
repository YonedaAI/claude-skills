# research-agent — MiMoCode

A MiMoCode Dynamic Workflow that orchestrates a multi-agent research pipeline. MiMo drafts
every artifact; AGY (Gemini) and Codex review independently. Takes comma-separated topics,
produces peer-reviewed arXiv-style papers with optional Haskell/Lean formal verification, a
deployed website, social posts, and Slack notifications.

## Usage

```
/research-agent "topic-a, topic-b, topic-c" --perspective "your framing"
```

| Flag | Description | Default |
|------|-------------|---------|
| `--perspective "..."` | Framing perspective for all papers | Inferred from project context |
| `--project <name>` | Project directory name | Derived from first topic |
| `--project-path <path>` | Where to create the project | Current working directory |
| `--github-org <org>` | GitHub organization | `YonedaAI` |
| `--slack-channel <ID>` | Slack channel for notifications | `$RESEARCH_SLACK_CHANNEL` or `C0AK269AVSA` |
| `--no-haskell` | Skip Haskell/Lean verification | Enabled |
| `--no-website` | Skip website build + deploy | Enabled |
| `--no-social` | Skip social posts | Enabled |
| `--human-readable` | Humanizer grep gate before compile | Off |
| `--code-audit` | Audit the code evidence appendix | Off |
| `--bib-gate` | Resolve every bibliography entry first | Off |
| `--plan-critique` | Critique the plan before Phase 2 | Off |

## Who writes, who reviews

| Artifact | Author | Independent reviewer |
|---|---|---|
| Research papers | MiMo (`xiaomi/mimo-v2.6-pro`) | AGY (Gemini 4 Argon High) |
| Synthesis paper | MiMo (`xiaomi/mimo-v2.6-pro`) | AGY (Gemini 4 Argon High) |
| Haskell / Lean code | MiMo (`xiaomi/mimo-v2.6-pro`) | Codex (`gpt-6.1-sol`) |
| Website / publication code | MiMo (`xiaomi/mimo-v2.6-flash`) | Codex (`gpt-6.1-sol`) |
| Knowledge base, social | MiMo (`xiaomi/mimo-v2.6-flash`) | — |

**The author never reviews its own work.** That is the load-bearing rule of the whole design.

> `mimo-v2.6-pro-ultraspeed` is not served by this plan (`400 Not supported model`) and is
> never referenced.

## Pipeline

```
Phase 1: Setup ──> Phase 2: Knowledge Base ──> Phase 3: Workers (parallel)
                                                   │
                               ┌───────────────────┼───────────────────┐
                               ▼                   ▼                   ▼
                          Topic A              Topic B              Topic N
                          Draft (20+ pages)    Draft (20+ pages)    Draft (20+ pages)
                          AGY Peer Review      AGY Peer Review      AGY Peer Review
                          MiMo Fix             MiMo Fix             MiMo Fix
                          Codex LaTeX Check    Codex LaTeX Check    Codex LaTeX Check
                          MiMo Fix             MiMo Fix             MiMo Fix
                          Compile PDF          Compile PDF          Compile PDF
                          Cover Image          Cover Image          Cover Image
                               │                   │                   │
                               └───────────────────┼───────────────────┘
                                                   ▼
Phase 4: Synthesis ──> Phase 5: Haskell Verify ──> Phase 6: Website + Deploy
                                                          │
                                                   Phase 7: Social Posts
                                                          │
                                                   Phase 8: Validate + Git + GitHub + Slack
```

Every phase is an `agent()` call in `workflows/research-agent.js`. Every gate fails closed:
an agent that resolves `null` aborts the run, and a `SKIPPED` review stub is a failure.

## Review pipeline

1. **AGY peer review** via `agy-review-shim` (`$RESEARCH_GEMINI_BIN`, model label
   `$RESEARCH_GEMINI_MODEL`, default `gemini-4-argon-high`) — adversarial review by an external LLM.
   Max **3** rounds. The plain `gemini` CLI is deprecated and never used.
2. **Codex formatting check** via `codex exec -s read-only` — LaTeX compilation, references,
   styling. Max **2** fix passes.

Both are serialized through a project-wide `.review.lock` mutex, and a sanity test of both
reviewers runs in Phase 1 before any worker spawns. Missing or stub reviews abort the run.

## Models

`xiaomi/mimo-v2.6-pro` for reasoning-heavy work, `xiaomi/mimo-v2.6-flash` for volume work.
Both against `https://token-plan-sgp.xiaomimimo.com/v1`. Claude is never used for drafting.

## Output structure

```
project/
├── papers/latex/*.tex          # LaTeX sources with GrokRxiv sidebar
├── papers/pdf/*.pdf            # Compiled PDFs
├── reviews/*.md                # AGY peer review rounds
├── src/*/                      # Haskell/Lean formal verification
├── images/*.png                # Cover images (300 DPI)
├── docs/papers/*.html          # Pandoc HTML conversions
├── website/                    # Next.js site (deployed)
│   └── public/og/*.png         # Open Graph images
├── posts/{twitter,linkedin,facebook,bluesky}/
├── prompts/                    # stage procedures this run executed
├── references/                 # writing + format standards
├── .knowledge-base.md
└── README.md
```

## Requirements

- MiMoCode with the Dynamic Workflow feature
- `agy` (Antigravity) CLI + `agy-review-shim` at `$RESEARCH_GEMINI_BIN`
  (default `/Users/mlong/.local/bin/agy-review-shim`)
- `codex` CLI (absolute path; Node is managed by `fnm`)
- `pdflatex`, `pandoc`, `ghc`/`cabal`/`stack`, `vercel`, `pdftoppm`
- A Slack MCP server named `slack` in `~/.config/mimocode/mimocode.jsonc` — local stdio
  (`npx -y @modelcontextprotocol/server-slack`) with `SLACK_BOT_TOKEN` + `SLACK_TEAM_ID`.
  Send tool: `mcp__slack__slack_post_message`. Bot identity is the dedicated **Research Agent**
  app (see `slack/research-agent-app.yaml`); credentials in `~/.config/research-agent/slack.env.json`.

## Layout

```
research-agent-skill/
├── skills/research-agent/SKILL.md   # MiMoCode skill entry point
├── workflows/research-agent.js      # 8-phase Dynamic Workflow
├── prompts/*.md                     # stage procedures (frontmatter-free)
└── references/*.md                  # writing + format standards
```

`references/` are the standards of record. When the skill and a reference disagree, the
reference wins.

## Branches

| Branch | Host |
|---|---|
| `claude` | Claude Code plugin format (`.claude-plugin/`, `commands/`, `agents/`) |
| `mimo` | MiMoCode skill + Dynamic Workflow (this branch) |
| `codex/research-agent-native-harness` | Codex native collaboration adapter |

## License

MIT — YonedaAI Research Collective
