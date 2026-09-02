# Team Protocol (`--multi-agent-team`) and Humanizer Rules (`--human-readable`)

Compact reference for two optional pipeline flags. Workers read this file when their prompt says `MULTI-AGENT TEAM: ON` or `HUMAN-READABLE: ON`; the orchestrator reads it for the integration gate (Phase 3) and the pre-compile checks (Phase 4.5).

## 1. Team protocol

Goal: parallel workers produce Parts that cite each other correctly, define every shared object exactly once, and use one notation.

### Files

| Path | Writer | Purpose |
|------|--------|---------|
| `team/<slug>/contract.md` | the worker for `<slug>` | Interface contract, written BEFORE drafting |
| `team/board.md` | every worker, orchestrator | Append-only event log (never rewrite, never delete lines) |
| `team/integration-review.md` | integration reviewer (orchestrator-spawned) | `VERDICT: INTEGRATED` or `VERDICT: CONFLICTS` + fix list |
| `team/<slug>/bib-check.md` | orchestrator (`--bib-gate`) | Bibliography resolution results for the Part |

`team/` is committed with the project (it is scholarly provenance, not process leakage, because nothing in it reaches the papers).

### Contract (`team/<slug>/contract.md`)

```
# Contract: <slug> (Part N)
## Defines            (objects this Part owns; other Parts cite, never redefine)
- <Object name> — <one-line meaning> — label `def:<slug>:<name>` / `thm:<slug>:<name>`
## Imports            (objects this Part uses but does not own)
- <Object name> — owned by Part M (<owner-slug>)
## Notation
- <symbol> : <meaning>
## Cross-references I will make
- Part M, <object>
```

Write it in five minutes from the knowledge base and the topic list; refine only if a sibling contract forces it.

### Board line format (`team/board.md`)

One line per event, appended with `>>`, UTC timestamp first:

```
<ISO-8601 UTC> <slug> <EVENT> <free text>
```

Events, in the order a worker emits them:

| EVENT | When | Free text |
|-------|------|-----------|
| `CONTRACT` | contract.md written | list of defined objects |
| `DRAFT` | first full draft on disk | `papers/latex/<slug>.tex`, page estimate |
| `RECONCILED` | cross-references checked against sibling drafts | what changed |
| `REVIEWED` | Gemini loop finished | rounds, final verdict |
| `BLOCKED` | reviewer failed twice, or a sibling never produced DRAFT | reason (orchestrator acts on this) |
| `DONE` | worker's final verification passed | — |

The orchestrator appends `INTEGRATION <VERDICT>` after the integration gate.

### Ownership rule

**The lower-numbered Part owns a shared object.** If Parts II and IV both need "the coalgebra of observations", Part II defines it (Definition, label `def:<part2-slug>:...`) and Part IV writes "Definition 2.3 of Part II" and cites it. Ties are impossible because Part numbers are unique. A worker that discovers it needs an object owned by a higher-numbered Part imports it anyway (cite forward: "defined in Part IV, Section 2") and appends a board line so the integration reviewer can check the forward reference.

### Bounded wait and peer integration step

1. After `DRAFT`, poll `team/board.md` every 60 s for sibling `DRAFT` lines. Wait at most 20 minutes; then proceed with whatever siblings exist and note missing ones in a `BLOCKED` line (do not exit; continue the pipeline).
2. Open each sibling `.tex` whose objects you import. For every `Part N` reference in your paper: confirm the object exists there, copy its exact theorem/definition number and label, and match its notation to the sibling contract.
3. Redefinitions of imported objects are removed and replaced with a citation. Conflicting notation is changed in the higher-numbered Part.
4. Append `RECONCILED` with a list of the references you fixed, then continue to the Gemini review loop.

### Integration reviewer gate (orchestrator, before Phase 4)

Spawned as a `general-purpose` agent after the post-worker review gate passes. Inputs: every `papers/latex/*.tex`, every contract, the board. Checks: (a) each shared object is defined once, by its owner; (b) every `Part N` cross-reference resolves to an existing numbered result; (c) notation matches the contracts. Output `team/integration-review.md` with `VERDICT: INTEGRATED` or `VERDICT: CONFLICTS` and lines `(<slug>, <object>, <fix>)`. On CONFLICTS the orchestrator respawns only the named workers from Stage 3 with the fix list; max 2 rounds.

## 2. Humanizer rules (`--human-readable`)

Apply while drafting and again before the final compile. They tighten scholarly prose; they never remove mathematics, citations, or hedges that are genuinely warranted.

1. No em dashes and no en dashes in prose (`—`, `–`). Use a comma, a colon, parentheses, or a new sentence. Number ranges use "to" ("pages 3 to 7") or a hyphen inside math mode only.
2. No `---` or `--` horizontal-rule/dash sequences in prose (LaTeX `\hrule`, tables, and `\cite` keys are exempt).
3. No AI-vocabulary words. Banned list: delve, tapestry, testament, underscore(s) (as a verb), pivotal, crucial, robust (outside statistics), seamless(ly), leverage (as a verb), navigate (metaphorical), landscape (metaphorical), realm, paradigm shift, groundbreaking, cutting-edge, unlock, harness, foster, holistic, nuanced, intricate, multifaceted, "it is worth noting", "it is important to note", "in today's", "in the realm of", "serves as", "stands as", "plays a vital role", "a rich", "vibrant".
4. Sentence-case headings: `\section{Compositional structure of observations}`, not Title Case. Proper nouns keep their capitals.
5. Straight quotes only: `"` and `'` in prose; LaTeX ``` `` ``` / `''` are fine because they compile to typographic quotes. No Unicode curly quotes in the source.
6. No bold-header bullet lists (`\item \textbf{Term.} explanation`). Use a paragraph, a `description` environment with plain labels, or a table.
7. Neutral scholarly voice: no promotional adjectives, no "we are excited", no rhetorical questions, no rule-of-three flourishes, no closing sentences that restate the paragraph. Claims are stated once, with their evidence.

### Humanizer grep checks

Run from the project root over every paper. The pipeline (Phase 4.5) and the worker (before Stage 7) both run them; every hit is fixed by editing prose, never by adding exceptions.

```bash
cd "$PROJECT_ROOT"
fail=0
for tex in papers/latex/*.tex; do
  echo "=== $tex ==="
  grep -nE '—|–' "$tex" && { echo "HIT: em/en dash"; fail=1; }
  grep -nE '(^|[^-])---?($|[^-])' "$tex" | grep -vE '\\(hrule|cite|ref|label|url|href|draw)|^[[:space:]]*%|&' && { echo "HIT: --- / -- in prose"; fail=1; }
  grep -niE '\b(delve|tapestry|testament|pivotal|crucial|seamless(ly)?|leverag(e|es|ing)|realm|groundbreaking|cutting-edge|unlock(s|ed|ing)?|harness(es|ed|ing)?|foster(s|ed|ing)?|holistic|nuanced|intricate|multifaceted|vibrant)\b|it is worth noting|it is important to note|in today.s|in the realm of|serves as|stands as|plays a vital role|paradigm shift' "$tex" && { echo "HIT: AI vocabulary"; fail=1; }
  grep -nE '\\(section|subsection|subsubsection)\*?\{[^}]*\b[A-Z][a-z]+ [A-Z][a-z]+' "$tex" | grep -vE '\{(A|An|The) [A-Z][a-z]+ ' && { echo "HIT: Title Case heading (check proper nouns manually)"; fail=1; }
  grep -nE '“|”|‘|’' "$tex" && { echo "HIT: curly quotes"; fail=1; }
  grep -nE '\\item[[:space:]]*\\textbf\{' "$tex" && { echo "HIT: bold-header bullet list"; fail=1; }
done
[ "$fail" = 0 ] && echo "HUMANIZER: CLEAN" || echo "HUMANIZER: FIX THE HITS ABOVE"
```

The Title Case check is heuristic: a heading such as `Hilbert Space Methods` is a hit, `Hilbert space methods` passes, and a genuine proper noun sequence (`Gelfand Naimark theorem`) may need a manual pass. Record the final clean run in `reviews/human-readable-check.md`.
