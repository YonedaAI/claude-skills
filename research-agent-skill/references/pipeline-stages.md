# Pipeline Stages — Dependency Graph

## Stage Dependencies

```
Phase 1: Setup
  └─── BLOCKS ──→ Phase 2

Phase 2: Knowledge Base (single agent, foreground)
  └─── BLOCKS ──→ Phase 3 (all workers)

Phase 3: Research Workers (parallel, one per topic)
  ├── Each worker is independent of other workers
  ├── Each worker runs: Draft → Gemini Review → Fix → Codex Check → Fix → PDF → Cover Image
  ├── Each worker sends Slack notification on completion
  └─── ALL must complete ──→ BLOCKS Phase 4

Phase 4: Synthesis Agent (single agent, foreground)
  ├── Reads all completed papers
  ├── Same sub-pipeline as workers
  └─── BLOCKS ──→ Phase 5, Phase 6

Phase 5: Haskell Verification (parallel per topic, can overlap with Phase 6 prep)
  ├── Each topic verified independently
  ├── Compile → Test → Codex Review → Fix
  └─── ALL must complete ──→ BLOCKS Phase 6 deployment

Phase 6: Website Build (sequential)
  ├── Step 6a: Pandoc conversion (all papers)
  ├── Step 6b: Next.js site build (website-builder agent)
  ├── Step 6c: OG images (og-image-generator, parallel with 6b)
  ├── Step 6d: Codex website review → Fix
  ├── Step 6e: Vercel deployment
  └─── BLOCKS ──→ Phase 7 (social posts need Vercel URL)

Phase 7: Social Posts (social-posts agent)
  ├── Needs Vercel URL for links
  ├── Generates posts for all platforms × all papers
  └─── BLOCKS ──→ Phase 8

Phase 8: Finalize
  ├── Generate README.md
  ├── git add + commit (ALL changes at once)
  ├── gh repo create --public
  ├── git push
  └── Final Slack summary
```

## Fix Loop Bounds

All review/fix cycles are bounded to prevent infinite loops:

| Review Type | Max Iterations | Action if unresolved |
|-------------|---------------|----------------------|
| Gemini peer review fix | 2 | Log remaining issues, continue |
| Codex LaTeX formatting fix | 2 | Log remaining issues, continue |
| Codex Haskell review fix | 2 | Log remaining issues, continue |
| Codex website review fix | 2 | Log remaining issues, continue |
| GHC compilation fix | 3 | Save error log, skip this module |
| pdflatex compilation fix | 3 | Save error log, skip PDF generation |

## Agent Spawning Patterns

| Pattern | When | Example |
|---------|------|---------|
| Single foreground | Need results before continuing | knowledge-base-builder, synthesis-agent |
| Parallel foreground | Multiple independent tasks | research-workers (all topics at once) |
| Background | Can overlap with other work | og-image-generator during website build |

**Rule**: Always send parallel agents in a single message with multiple Agent tool calls so they run concurrently.

## Slack Notification Points

1. Each research worker completion → per-topic notification
2. Synthesis completion → synthesis notification
3. Haskell verification completion → verification notification
4. Vercel deployment → deployment notification with URL
5. Final summary → comprehensive summary with all links
