# Codex runtime adapter

Apply this file only when the research-agent skill runs inside Codex with native collaboration tools. These rules override conflicting Codex-related instructions in `SKILL.md` and its supporting agent prompts. They do not change the Claude Code path.

## Native harness only

Coordinate work through the Codex collaboration harness:

- `spawn_agent` starts a bounded independent assignment.
- `send_message` shares a dependency or correction with running work.
- `followup_task` gives a completed or idle agent another pass.
- `wait_agent` joins a wave.
- `interrupt_agent` stops obsolete or misdirected work.
- `list_agents` reports the live team.

Subagents inherit the active Codex session model, reasoning configuration, permissions, and concurrency limit. Do not invoke `codex`, `codex exec`, `codex review`, or `codex:rescue`. Do not reproduce session settings with `-m` or `-c`.

Choose agents from the useful independent work. A number in a user prompt, including "25+ agents," is an example of desired breadth, not an exact quota. Rotate agents through waves when assignments outnumber the available slots.

## Do not build orchestration

The research output is the product. Never create an orchestrator, agent platform, task server, queue, registry, routing adapter, manifest protocol, capability system, receipt system, staleness system, SSH controller, or workflow engine for a research run.

Do not create `orchestrator.py`, an orchestration shell driver, an agent-control `Makefile`, or similar infrastructure. Only build orchestration software when the user explicitly asks for orchestration software as the deliverable.

Use a short artifact checklist for status. Interrupt any agent that starts building a coordination platform and restate its scientific or publication deliverable.

## Codex authorship and independent review

The orchestrating host model IS the drafter — under the Codex harness that is the
session's Codex model (or `RESEARCH_DRAFTER_MODEL` when set). Reviewers stay external:
**reviewers are never the main model drafting.**

Use this assignment matrix (host-model drafting + reviewer swap rules):

| Artifact | Author and fixer | Independent reviewer |
|---|---|---|
| Research papers | the host model (Codex native agents) | AGY |
| Synthesis paper | the host model (Codex native agent) | AGY |
| Lean, Haskell, and supporting code | the host model (Codex native agents) | Claude |
| Website and publication code | the host model (Codex native agents) | Claude |

The host family here is `openai`/`codex`, so the code lane swaps to Claude — **Codex
NEVER reviews itself.** AGY reviews scientific papers; Claude reviews code. Do not assign
Codex as its own independent reviewer in any lane. Reviewer defaults live in
`settings/research-agent.settings.json`; the swap table is mirrored in
`core/references/harness-matrix.md`.

The following legacy stages are disabled in Codex runs:

- Codex LaTeX formatting review
- Codex synthesis formatting review
- Codex Haskell review
- Codex website review
- `codex:rescue` invocations
- `*-codex-review*` artifacts

Codex authors still compile LaTeX, build the website, run tests, and correct ordinary authoring defects. Independent review follows the matrix above.

## AGY paper review

Resolve the configured AGY shim without changing its existing CLI contract:

```bash
AGY="${RESEARCH_GEMINI_BIN:-/Users/mlong/.local/bin/agy-review-shim}"
test -x "$AGY" || AGY="$(command -v agy-review-shim)"
test -n "$AGY" || { echo "AGY paper reviewer unavailable"; exit 1; }
```

Use AGY for each paper and the synthesis. The science-reviewer models are AGY primary
`Gemini 3.8 Flash (Medium)` with fallback `Gemini 4 Argon (High)`
(`settings/research-agent.settings.json` → `reviewers.science`; `AGY_REVIEW_MODEL` /
`AGY_REVIEW_FALLBACK_MODEL` carry the labels written into review files). Ask it to check
correctness, assumptions, novelty, missing literature, overclaims, and exposition.
Preserve the existing review-fix-review loop and publishable-verdict gate, but label the
reviewer AGY rather than Codex or a generic Gemini reviewer.

Save paper review rounds under `reviews/<topic>-agy-review-round-N.md`, with a canonical `reviews/<topic>-agy-review.md`. Codex fixes actionable findings, rebuilds the paper, and requests another AGY review when required.

## Claude code review (subscription only)

Resolve Claude from the configured environment or `PATH`. `RESEARCH_CLAUDE_BIN`
must identify the direct Claude CLI binary, not a wrapper that injects
credentials:

```bash
CLAUDE="${RESEARCH_CLAUDE_BIN:-$(command -v claude)}"
test -n "$CLAUDE" || { echo "Claude code reviewer unavailable"; exit 1; }
CLAUDE_MODEL="${RESEARCH_CLAUDE_MODEL:-opus[1m]}"

case "$CLAUDE_MODEL" in
  *[Ff][Aa][Bb][Ll][Ee]*)
    echo "Fable models are prohibited for research-agent code review"
    exit 1
    ;;
esac

run_claude_subscription() {
  env \
    -u ANTHROPIC_API_KEY \
    -u ANTHROPIC_AUTH_TOKEN \
    -u ANTHROPIC_BASE_URL \
    -u ANTHROPIC_BEDROCK_BASE_URL \
    -u ANTHROPIC_VERTEX_BASE_URL \
    -u ANTHROPIC_FOUNDRY_BASE_URL \
    -u CLAUDE_CODE_USE_BEDROCK \
    -u CLAUDE_CODE_USE_VERTEX \
    -u CLAUDE_CODE_USE_FOUNDRY \
    "$CLAUDE" "$@"
}

CLAUDE_AUTH_JSON="$(run_claude_subscription auth status --json)"
printf '%s\n' "$CLAUDE_AUTH_JSON" \
  | grep -Eq '"authMethod"[[:space:]]*:[[:space:]]*"claude\.ai"' \
  || {
    echo "Claude review requires claude.ai subscription authentication; API or provider authentication is prohibited"
    exit 1
  }
printf '%s\n' "$CLAUDE_AUTH_JSON" \
  | grep -Eq '"subscriptionType"[[:space:]]*:[[:space:]]*"[^"]+"' \
  || {
    echo "Claude review requires an active Claude subscription"
    exit 1
  }
```

Invoke every Claude review through `run_claude_subscription`, pass
`--model "$CLAUDE_MODEL"` explicitly, and do not configure a fallback model.
Do not use `--max-budget-usd`: subscription usage is governed by the plan, and
a dollar budget is not the authentication or safety boundary. Use
`--max-turns` when a bounded non-interactive review is useful.

Example read-only invocation:

```bash
run_claude_subscription -p \
  --model "$CLAUDE_MODEL" \
  --permission-mode plan \
  --tools Read Grep Glob Bash \
  --disallowedTools Edit Write NotebookEdit \
  --no-session-persistence \
  --max-turns 12 \
  "$REVIEW_PROMPT"
```

Never invoke `"$CLAUDE"` directly for a research-agent review. The wrapper
removes API keys, bearer tokens, custom gateways, and cloud-provider routing
from the review process before the Claude subprocess starts. If the
subscription preflight fails, stop the review rather than falling back to API
billing, Bedrock, Vertex, Foundry, Fable, or another model.

Use Claude as a read-only independent reviewer for Lean, Haskell, scripts, and website code. Ask for concrete findings and one terminal line:

```text
VERDICT: PASS
```

or:

```text
VERDICT: NEEDS_FIX
```

Save rounds as `reviews/<artifact>-claude-code-review-round-N.md`, with a canonical `reviews/<artifact>-claude-code-review.md`. Codex verifies each finding, fixes valid issues, reruns native builds and tests, then requests another Claude pass when needed.

Claude review does not replace GHC, Cabal, Lake, Lean checking, frontend builds, browser checks, or source validation.

## Codex gate substitutions

Do not run the legacy `review_gate_check` or `haskell_review_gate` functions verbatim during a Codex run. Their Gemini and `*-codex-review*` filenames belong only to the unchanged Claude Code path.

Apply the same fail-closed semantics with Codex-native names:

- Require `reviews/<topic>-agy-review-round-1.md` and `reviews/<topic>-agy-review.md` for every paper and the synthesis. Require substantive content and a publishable terminal verdict. If the paper changes after the canonical review, request another AGY round and replace the canonical file with that final round.
- Require `reviews/<artifact>-claude-code-review-round-1.md` and `reviews/<artifact>-claude-code-review.md` for every requested Lean, Haskell, script, and website artifact. Require substantive content and terminal `VERDICT: PASS`. If code changes after the canonical review, rerun native checks and request another Claude round.
- Never satisfy a gate by creating a legacy `*-codex-review*` file, a `SKIPPED` stub, or a renamed copy from a different reviewer.
- Abort publication when either adapted gate remains unsatisfied after the allowed correction loop.

## Concise plan contract

When the user requests a plan before execution, produce only:

- one short master checklist;
- one concise brief per paper;
- one synthesis brief when requested.

Each paper brief contains its research question, strongest defensible target, dependencies, deliverables, verification and review gates, and explicit nonclaims.

Do not include orchestration architecture, agent manifests, hashes, receipts, adapters, capability probes, SSH experiments, or a fixed agent count in the plan.

Ignore the legacy eight-line user-facing plan template during Codex runs. In particular, do not list disabled Codex formatting or Codex website-review stages.

## Execution loop

Run each artifact through:

1. **Plan:** define the claim, assumptions, sources, artifact, and verification test.
2. **Act:** research or author the smallest coherent unit.
3. **Verify:** check sources, mathematics, builds, tests, and independent review.
4. **Repeat:** fix the concrete failure and rerun the failed checks.

Keep research papers in standard arXiv scholarly form. Do not add pipeline badges, result-status labels, or verification taxonomies to titles, abstracts, theorem statements, tables, or publication copy. State scope through explicit hypotheses and conventional environments such as Theorem, Proposition, Lemma, Conjecture, Remark, and Limitations. Lean compilation does not erase axioms, `sorry`, or missing hypotheses, and Haskell tests provide computational evidence rather than theorem proofs; record those distinctions in ordinary verification notes outside the paper's scholarly presentation. After the paper's independent scientific review and all substantive fixes are complete, add the GrokRxiv page-one sidebar from `references/paper-format.md`, then run the final PDF build.

## Publication rules

Preserve the existing repository, paper, website, Vercel, social, and Slack stages unless the user disables them. For a Codex run:

- Codex agents implement publication artifacts.
- Claude reviews website and publication code.
- Focused Codex fixers may check responsive layout, HTML, accessibility, and mathematics rendering as author-side verification.
- Deploy or publish only with user authorization.
- Send Slack messages only after stable public links resolve.
- Format Slack links as `<https://example.com>` or `<https://example.com|label>`.

Replace the legacy Slack reviewer sentence with a truthful runtime-specific summary such as: `Papers reviewed by AGY; Lean, Haskell, and website code reviewed by Claude.` Do not claim that Codex independently reviewed its own work.

## Codex completion gate

- [ ] Native collaboration tools coordinated every agent assignment.
- [ ] Agent count followed useful parallel work and available slots.
- [ ] No nested Codex process or custom orchestration system was created.
- [ ] Codex authored and revised all requested papers and code.
- [ ] AGY reviewed every paper and the synthesis.
- [ ] Claude reviewed all requested code.
- [ ] Every Claude review passed the subscription-authentication preflight with API and provider credentials removed.
- [ ] Builds, tests, formal checks, and rendered-site checks were rerun after fixes.
- [ ] Papers use standard scholarly conventions, and verification notes distinguish kernel-checked proofs from assumptions and computational tests without publication-facing status labels.
- [ ] Public links resolve before Slack notification.
