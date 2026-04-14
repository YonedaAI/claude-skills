---
name: research-agent
description: "Use when the user asks to research topics, generate research papers, run a research pipeline, create academic papers with peer review, or invokes /research-agent. Orchestrates parallel research agents with Gemini peer review, Codex formatting checks, optional Haskell verification, Vercel website deployment, multi-platform social posts, and Slack notifications."
version: 0.1.0
---

# Research Agent Pipeline — Orchestration

This skill orchestrates an 8-phase multi-agent research pipeline. Each phase spawns specialized agents that draft, review, verify, publish, and promote research papers.

## Input Contract

The command passes these parsed values:
- `$TOPICS` — array of research topic slugs (e.g. `["quantum-gravity", "entanglement"]`)
- `$PERSPECTIVE` — framing perspective for all papers
- `$PROJECT` — project directory name
- `$PROJECT_PATH` — absolute path to create project (default: cwd)
- `$GITHUB_ORG` — GitHub organization (from `$RESEARCH_GITHUB_ORG` env var or default `YonedaAI`)
- `$SLACK_CHANNEL` — Slack channel ID (from `$RESEARCH_SLACK_CHANNEL` env var or default `C0AK269AVSA`)
- `$SKIP_HASKELL`, `$SKIP_WEBSITE`, `$SKIP_SOCIAL` — boolean flags

## Environment Variables

Read these at the start of execution. All have sensible defaults — none are required.

| Env Var | Default | Purpose |
|---------|---------|---------|
| `RESEARCH_AUTHOR_NAME` | `Matthew Long` | Paper author name |
| `RESEARCH_AUTHOR_EMAIL` | `matthew@yonedaai.com` | Author contact email |
| `RESEARCH_AUTHOR_URL` | `https://yonedaai.com` | Author website |
| `RESEARCH_COLLABORATION` | `The YonedaAI Collaboration` | Collaboration line in author block |
| `RESEARCH_INSTITUTION` | `YonedaAI Research Collective` | Institution line in author block |
| `RESEARCH_LOCATION` | `Chicago, IL` | Author location |
| `RESEARCH_GITHUB_ORG` | `YonedaAI` | GitHub organization for repo creation |
| `RESEARCH_SLACK_CHANNEL` | `C0AK269AVSA` | Slack channel ID for notifications |
| `RESEARCH_GEMINI_MODEL` | `gemini-3.1-pro` | Gemini model for peer review |
| `RESEARCH_WORKER_MODEL` | `opus` | Model for research-worker and synthesis agents |
| `RESEARCH_UTILITY_MODEL` | `sonnet` | Model for utility agents (KB builder, website, social) |

## CRITICAL — Mandatory Steps (never skip these)

Every phase has a MANDATORY checkpoint. You MUST complete ALL of these — they are not optional:

1. **Gemini peer review loop** — Every paper (workers + synthesis) MUST be reviewed by `gemini -m $RESEARCH_GEMINI_MODEL` in an iterative loop: review → fix → re-review → fix → ... until the reviewer's VERDICT is ACCEPT or MINOR REVISIONS. Max 4 rounds per paper. Reviews saved to `reviews/$TOPIC-review-round-N.md`. Skipping this is a pipeline failure.
2. **Codex formatting check** — Every paper MUST be checked by `codex:rescue` after the review loop. Skipping this is a pipeline failure.
3. **Codex website review** — The website MUST be reviewed by `codex:rescue` BEFORE Vercel deployment (Step 6d). Skipping this is a pipeline failure.
4. **Slack per-topic notifications** — Send a Slack message after EACH worker completes, after synthesis completes, after Haskell verification completes, after website deployment, and a final summary. These are 5+ separate Slack messages minimum.
5. **Review-fix loops** — After each Gemini review, you MUST fix critical/major issues and re-submit until the verdict is publishable (ACCEPT/MINOR REVISIONS) or 4 rounds are exhausted. After Codex review, max 2 fix iterations.

If you present a plan to the user, the plan MUST explicitly list all 5 of the above as separate line items. Do not collapse them into a phase header.

---

## Author Block (used in all papers)

Constructed from env vars at runtime:

```
$RESEARCH_AUTHOR_NAME
$RESEARCH_COLLABORATION
$RESEARCH_INSTITUTION
$RESEARCH_LOCATION
$RESEARCH_AUTHOR_EMAIL · $RESEARCH_AUTHOR_URL
```

---

## Phase 1 — Project Setup

Create the project directory and initialize git:

```bash
mkdir -p $PROJECT_PATH/$PROJECT/{papers/{latex,pdf},src,reviews,posts/{twitter,linkedin,facebook,bluesky},images,docs/papers,website}
cd $PROJECT_PATH/$PROJECT && git init
```

Copy reusable conversion tools if available in the working directory:
```bash
# Copy from yoneda-ai or similar project if present
cp scripts/latex2html.py $PROJECT_PATH/$PROJECT/scripts/ 2>/dev/null || true
cp scripts/paper-template.html $PROJECT_PATH/$PROJECT/scripts/ 2>/dev/null || true
```

---

## Phase 2 — Knowledge Base

Spawn a single `knowledge-base-builder` agent (foreground, blocks everything else).

**Agent prompt:**
```
You are building a knowledge base for a research project.

Project: $PROJECT at $PROJECT_PATH/$PROJECT
Perspective: $PERSPECTIVE
Topics to research: $TOPICS (joined as comma list)

1. Search for source files: glob `sources/**/*.{tex,md,pdf}` in the project dir and parent directories
2. For each source file found:
   - Extract: title, authors, abstract, key concepts, frameworks, theorems
3. Build a cross-reference section showing how sources relate
4. Write the output to `$PROJECT_PATH/$PROJECT/.knowledge-base.md`

If no source files exist, create a knowledge base from web research on the topics using WebSearch.
The knowledge base should provide enough context for each topic to write a 20+ page paper.
```

Wait for the agent to complete and verify `.knowledge-base.md` exists before proceeding.

---

## Phase 3 — Research Workers (Parallel)

For EACH topic in `$TOPICS`, spawn a `research-worker` agent **in parallel** (all in a single message with multiple Agent tool calls).

**Agent prompt per topic:**
```
You are a research worker writing a paper on: $TOPIC
Perspective: "$PERSPECTIVE, analyze and formalize $TOPIC"
Project root: $PROJECT_PATH/$PROJECT

Read .knowledge-base.md for context, then execute this pipeline:

### Stage 1 — Draft
Write an arxiv-style LaTeX paper (>=20 pages) to `papers/latex/$TOPIC.tex`
Include: abstract, introduction, mathematical framework, results, discussion, references.
Use standard article class, amsmath, amssymb, tikz-cd, hyperref, cleveref.
Add custom theorem environments (Theorem, Proposition, Lemma, Definition, Remark).

Author block:
$RESEARCH_AUTHOR_NAME
$RESEARCH_COLLABORATION, $RESEARCH_INSTITUTION
$RESEARCH_LOCATION
$RESEARCH_AUTHOR_EMAIL · $RESEARCH_AUTHOR_URL

If the topic involves mathematics, also create Haskell modules in `src/$TOPIC/`:
- Main.hs with runnable demonstrations
- Supporting modules for key abstractions
- Each file must compile with GHC

### Stages 2–3 — Gemini Review-Fix Loop
Run iterative peer review via Gemini CLI. Submit paper → fix issues → re-submit until verdict is ACCEPT or MINOR REVISIONS. Max 4 rounds.

Each round: run Bash command to pipe paper to gemini with review prompt that ends with a VERDICT line (REJECT / MAJOR REVISIONS / MINOR REVISIONS / ACCEPT). Save each round to `reviews/$TOPIC-review-round-N.md`. Fix critical/major issues between rounds. Copy final review to `reviews/$TOPIC-review.md`.

See the research-worker agent definition for the exact Bash command and loop logic.

### Stage 4 — Codex LaTeX Formatting Check
Invoke the `codex:rescue` skill to review LaTeX formatting. Fix all issues. Max 2 fix iterations.

### Stage 5 — Add GrokRxiv Sidebar
Add the GrokRxiv DOI sidebar to page 1 of the paper. See references/paper-format.md for the template.
DOI slug: current year.month.$TOPIC
Category: choose appropriate arXiv-style category
Date: today's date

### Stage 6 — Compile PDF
Run these Bash commands:

    cd $PROJECT_PATH/$PROJECT/papers/latex
    pdflatex -interaction=nonstopmode $TOPIC.tex
    pdflatex -interaction=nonstopmode $TOPIC.tex

If compilation fails, read the .log file, fix errors, recompile. Repeat until clean.
Move PDF: `cp $TOPIC.pdf ../pdf/`
Clean artifacts: `rm -f *.aux *.log *.toc *.out *.bbl *.blg *.nav *.snm *.vrb *.fls *.fdb_latexmk *.synctex.gz`

### Stage 7 — Generate Cover Image
Run these Bash commands:

    mkdir -p $PROJECT_PATH/$PROJECT/images
    pdftoppm -png -f 1 -l 1 -r 300 "$PROJECT_PATH/$PROJECT/papers/pdf/$TOPIC.pdf" "$PROJECT_PATH/$PROJECT/images/$TOPIC"
    mv "$PROJECT_PATH/$PROJECT/images/$TOPIC-1.png" "$PROJECT_PATH/$PROJECT/images/$TOPIC.png" 2>/dev/null || true

MANDATORY CHECKLIST — Do NOT proceed to the next stage until each box is done:
[ ] Stage 1: papers/latex/$TOPIC.tex exists and is >=20 pages
[ ] Stages 2–3: reviews/$TOPIC-review.md exists with Gemini ACCEPT/MINOR REVISIONS verdict
[ ] Stage 4: Codex formatting check run via codex:rescue skill, issues fixed
[ ] Stage 5: GrokRxiv sidebar added to page 1
[ ] Stage 6: papers/pdf/$TOPIC.pdf exists and compiles cleanly
[ ] Stage 7: images/$TOPIC.png exists (300 DPI cover)

When complete, report: topic name, paper page count, whether Haskell code was created, PDF compilation status, Gemini review (rounds completed, final verdict), Codex issues (count found → count fixed).
```

**MANDATORY — Post-Worker Review Verification:**

After ALL workers complete, verify that reviews actually happened and reached a publishable verdict. Run this Bash command:

    echo "=== REVIEW VERIFICATION ==="
    for topic in $TOPICS; do
      if test -f reviews/$topic-review.md; then
        size=$(wc -c < reviews/$topic-review.md)
        verdict=$(tail -20 reviews/$topic-review.md | grep -i "VERDICT" | tail -1)
        rounds=$(ls reviews/$topic-review-round-*.md 2>/dev/null | wc -l)
        if [ "$size" -lt 100 ]; then
          echo "FAIL: reviews/$topic-review.md too small ($size bytes) — review was likely skipped"
        elif [ "$rounds" -eq 0 ]; then
          echo "FAIL: No review round files — worker did not run iterative review loop"
        else
          echo "PASS: reviews/$topic-review.md ($size bytes, $rounds rounds) $verdict"
        fi
      else
        echo "FAIL: reviews/$topic-review.md MISSING — worker skipped Gemini review entirely"
      fi
    done

If ANY review file is MISSING, too small, or has no round files, the worker skipped the review loop. You MUST run the full review loop for that topic yourself:

1. Submit to Gemini with VERDICT prompt (see research-worker agent for exact command)
2. Fix critical/major issues
3. Re-submit until ACCEPT/MINOR REVISIONS or 4 rounds
4. Copy final round to `reviews/$TOPIC-review.md`

Do NOT proceed to Phase 4 until ALL reviews pass verification.

**MANDATORY — Slack notification per completed topic:**

After EACH worker completes (not after all — after EACH one), immediately send a Slack notification using `mcp__claude_ai_Slack__slack_send_message` to channel `$SLACK_CHANNEL`:

```
Research paper completed: $TOPIC
Pages: [count]
PDF: papers/pdf/$TOPIC.pdf
Haskell: [yes/no]
Gemini review: [N] rounds, final verdict: [ACCEPT/MINOR REVISIONS/etc]
Codex check: [issues found] → [issues fixed]
Review files: reviews/$TOPIC-review-round-*.md
```

---

## Phase 4 — Synthesis Agent

After ALL research workers complete, spawn `synthesis-agent` (foreground):

**Agent prompt:**
```
You are a synthesis agent combining multiple research papers into a unified work.

Project root: $PROJECT_PATH/$PROJECT
Perspective: $PERSPECTIVE
Topics: $TOPICS (all of them)

1. Read ALL papers in papers/latex/*.tex
2. Read .knowledge-base.md
3. Write papers/latex/synthesis.tex — a synthesis paper that:
   - Unifies all topics under the perspective
   - Identifies cross-cutting themes and emergent properties
   - References individual papers as Parts I, II, III, etc.
   - Shows how topics compose hierarchically
   - Minimum 20 pages, arxiv-style

4. Run Gemini peer review (same as workers — gemini -m $RESEARCH_GEMINI_MODEL)
5. Fix review issues (max 2 iterations)
6. Run Codex LaTeX check via codex:rescue skill, fix issues
7. Add GrokRxiv sidebar
8. Compile PDF (pdflatex twice, fix errors)
9. Generate cover image (pdftoppm)

Author block same as worker papers.
```

**MANDATORY — Synthesis checkpoint before proceeding:**
- [ ] papers/latex/synthesis.tex exists and is >=20 pages
- [ ] reviews/synthesis-review.md exists with Gemini output
- [ ] Review feedback addressed
- [ ] Codex formatting check run and issues fixed
- [ ] GrokRxiv sidebar added
- [ ] papers/pdf/synthesis.pdf compiles cleanly
- [ ] images/synthesis.png cover image generated

**MANDATORY — Slack notification on synthesis completion** using `mcp__claude_ai_Slack__slack_send_message` to `$SLACK_CHANNEL`:
```
Synthesis paper completed
Topics unified: [list]
Pages: [count]
Gemini review: [issues found] → [issues fixed]
Codex check: [issues found] → [issues fixed]
```

---

## Phase 5 — Haskell Verification

**Skip if `$SKIP_HASKELL` is true.**

For each topic that has code in `src/$TOPIC/`, spawn `haskell-verifier` agents in parallel:

**Agent prompt per topic:**
```
You are a Haskell formal verification agent using a layered proof strategy.

Project root: $PROJECT_PATH/$PROJECT
Topic: $TOPIC
Source directory: src/$TOPIC/

PHASE 1 — Structure and Compilation:
1. Read all .hs files in src/$TOPIC/
2. Ensure these modules exist: Main.hs, Core.hs (or domain-named), Properties.hs, Proofs.hs
3. If Properties.hs or Proofs.hs don't exist, CREATE them:
   - Properties.hs: QuickCheck properties for each major theorem in the paper
   - Proofs.hs: Equational reasoning proofs with executable checks
4. Compile with strict flags:

       cd $PROJECT_PATH/$PROJECT && ghc -Wall -Wextra -Werror -o src/$TOPIC/test src/$TOPIC/Main.hs src/$TOPIC/*.hs -isrc/$TOPIC -package QuickCheck 2>&1

5. Fix compilation errors (max 3 iterations)

PHASE 2 — QuickCheck Property Testing:
6. Ensure Properties.hs has at least one property per major theorem/proposition
7. Compile and run properties:

       cd $PROJECT_PATH/$PROJECT && ghc -Wall -o src/$TOPIC/props src/$TOPIC/Properties.hs -isrc/$TOPIC -package QuickCheck 2>&1 && src/$TOPIC/props

8. All properties MUST pass. If any fail, fix the implementation and rerun.

PHASE 3 — Equational Reasoning:
9. Ensure Proofs.hs contains equational proofs in structured format
10. Each proof must cite which paper theorem it verifies
11. Run proof checks via Main.hs

PHASE 4 — Liquid Haskell (optional):
12. Check if Liquid Haskell is available: `which liquid`
13. If available, add refinement type annotations and run `liquid src/$TOPIC/Core.hs`
14. If not available, skip and note in report

PHASE 5 — Codex Review:
15. Invoke codex:rescue skill: "Review Haskell in src/$TOPIC/ for: type safety, QuickCheck property correctness, equational proof soundness, missing coverage, idiomatic style."
16. Fix issues (max 2 iterations)

PHASE 6 — Final Verification:
17. Recompile everything, rerun all properties and proofs
18. Main.hs must exit 0 (all verifications pass)
19. Clean up: `rm -f src/$TOPIC/test src/$TOPIC/props src/$TOPIC/*.o src/$TOPIC/*.hi`

Report: compilation status, QuickCheck (N properties, all passed/failures), equational proofs (N checked/passed), Liquid Haskell (verified/skipped), Codex issues fixed.
```

**MANDATORY — Haskell checkpoint before proceeding:**
- [ ] All src/$TOPIC/ directories compile with `-Wall -Wextra -Werror` and zero warnings
- [ ] Properties.hs exists with QuickCheck properties for major theorems — all pass
- [ ] Proofs.hs exists with equational reasoning proofs — all executable checks pass
- [ ] Main.hs exits 0 (all verifications pass)
- [ ] Codex review completed, issues fixed

**MANDATORY — Slack notification on Haskell verification completion** using `mcp__claude_ai_Slack__slack_send_message` to `$SLACK_CHANNEL`:
```
Haskell verification completed
Topics verified: [list]
Modules compiled: [count]
QuickCheck: [N] properties tested, [N] passed
Equational proofs: [N] checked, [N] passed
Liquid Haskell: [verified/skipped]
Codex issues fixed: [count]
```

---

## Phase 6 — Website Build

**Skip if `$SKIP_WEBSITE` is true.**

### Step 6a — Pandoc Conversion

Convert all papers (including synthesis) to HTML. Run this Bash command:

    cd $PROJECT_PATH/$PROJECT
    for tex in papers/latex/*.tex; do
      name=$(basename "$tex" .tex)
      pandoc "$tex" --to html5 --mathjax --toc --toc-depth=3 --number-sections --no-highlight --wrap=none -o "docs/papers/$name.html"
    done

NOTE: Use `--mathjax` (not `--katex`) for pandoc conversion. This wraps math in `\(...\)` and `\[...\]` delimiters that KaTeX renderToString() can process at build time. The `--katex` flag inlines KaTeX HTML which often breaks complex expressions.

**MANDATORY — Extract custom LaTeX macros before math rendering:**
Papers define custom commands via `\newcommand` in their preambles (e.g. `\newcommand{\Hilb}{\mathcal{H}}`). These MUST be extracted and passed to KaTeX as macros, otherwise they render as red error text.

1. Parse all `papers/latex/*.tex` for `\newcommand{\name}[args]{definition}` lines
2. Convert each to a KaTeX macro entry: `'\\name': 'definition'`
3. Merge with base macros (`\slashed`, `\bra`, `\ket`, `\braket`, `\Hom`, `\Tr`, etc.)
4. Pass the full macro map to `katex.renderToString()` in `lib/render-math.ts`

This is critical — research papers routinely define 50-70 custom commands. Missing ANY of them causes visible red errors on the website.

If `scripts/latex2html.py` exists, prefer using it for better post-processing:

    python3 scripts/latex2html.py --latex-dir papers/latex --html-dir docs/papers --template scripts/paper-template.html --project-title "$PROJECT" --papers "topic:Title:Part N" ...

**MANDATORY — Math verification after conversion:**
For each converted HTML file, check for broken math by searching for raw LaTeX that wasn't wrapped in math delimiters:

    cd $PROJECT_PATH/$PROJECT/docs/papers
    for html in *.html; do
      echo "=== $html ==="
      # Find raw LaTeX commands outside of math delimiters
      grep -oP '(?<![\\(\[])\\(textbf|textit|mathcal|frac|sqrt|sum|prod|int|partial|nabla|infty|alpha|beta|gamma|delta|epsilon|lambda|mu|sigma|omega|psi|phi|Psi|Phi|mathbb|mathrm|operatorname|slashed|bar|hat|tilde|vec)\b' "$html" | head -20
    done

Fix any raw LaTeX found outside math delimiters by wrapping in `\(...\)` for inline or `\[...\]` for display math. Common issues to fix:
- `$$...$$` not converted: replace with `\[...\]`
- Inline `$...$` not converted: replace with `\(...\)`
- `\textbf{}` outside math: convert to `<strong>`
- `\textit{}` outside math: convert to `<em>`
- `\slashed{D}` — KaTeX doesn't support `\slashed`: replace with `\not{D}` or `{D\!\!\!/}`
- Subscripts/superscripts in prose (e.g. `SU(2)_L`): wrap in `\(...\)`

### Step 6b — Next.js Website

Spawn `website-builder` agent (foreground):

**Agent prompt:**
```
You are building a modern, mobile-ready research website with a UNIQUE theme derived from the research topics.

Project root: $PROJECT_PATH/$PROJECT
Papers: [list all topics + synthesis with titles]
Perspective: $PERSPECTIVE
Topics: $TOPICS
GitHub org: $GITHUB_ORG
Project name: $PROJECT

## STEP 0 — Design a Topic-Driven Theme

DO NOT use generic colors. Design a unique color palette and visual identity based on the research topics and perspective. Follow this process:

1. Analyze the research domain:
   - Physics/quantum: deep blues, ultraviolet, particle-trail glows
   - Mathematics/category theory: geometric purples, abstract gradients
   - Biology/neuroscience: organic greens, neural network patterns
   - Computer science/AI: electric cyan, circuit-board motifs
   - Chemistry: molecular oranges, reaction-energy yellows
   - Cosmology/gravity: dark space blacks, nebula gradients, stellar golds
   - Economics/social: warm earth tones, network graphs
   - Philosophy/epistemology: deep magentas, contemplative dark palettes

2. Generate a CSS variables block with these required tokens:
   --bg:            (dark background — always dark for readability)
   --surface:       (slightly lighter than bg, for cards/panels)
   --surface-hover: (hover state for surface elements)
   --accent:        (primary accent — derived from topic domain)
   --accent-hover:  (lighter variant of accent)
   --accent-glow:   (accent at ~15% opacity, for subtle glows)
   --accent-secondary: (complementary accent for variety)
   --text:          (light text on dark bg — high contrast)
   --text-muted:    (secondary text)
   --text-dim:      (tertiary/disabled text)
   --border:        (subtle borders)
   --code-bg:       (code block background, darker than bg)
   --success:       (status color)
   --warning:       (status color)

3. Design topic-specific visual touches:
   - Hero section gradient or pattern that evokes the research domain
   - Card hover effects that match the topic energy (e.g. glow for quantum, grow for biology)
   - A subtle background texture or SVG pattern relevant to the field
   - Typography choices that match the tone (e.g. serif for classical physics, sans for CS)

4. Write the complete theme to `website/theme.json` so it can be referenced:
   {
     "name": "theme-name-based-on-topics",
     "domain": "detected research domain",
     "colors": { "bg": "#...", "accent": "#...", ... },
     "font": "Inter|Crimson Pro|JetBrains Mono|...",
     "heroGradient": "linear-gradient(...)",
     "cardEffect": "glow|grow|slide|fade",
     "bgPattern": "description of SVG/CSS pattern"
   }

## STEP 1 — Create Next.js Project

Run this Bash command:

    cd $PROJECT_PATH/$PROJECT && npx create-next-app@14 website --typescript --tailwind --app --no-src-dir --no-import-alias --use-npm

## STEP 2 — Build Pages

**app/layout.tsx**: Root layout with:
- Topic-appropriate font from next/font/google (chosen in theme)
- Dark theme using the generated CSS variables
- Global OG meta tags
- Navigation header with project title

**app/page.tsx**: Landing page with:
- Hero section with topic-driven gradient/pattern and project title
- Brief perspective description
- Paper cards grid (responsive: 1 col mobile, 2 col tablet, 3 col desktop)
- Each card: cover image, title, part number, abstract excerpt (first 150 chars)
- Card hover effects matching the topic theme
- Links: "Read" (HTML page), "PDF" (download), "Code" (GitHub src link)

**app/papers/[slug]/page.tsx**: Individual paper pages with:
- Full paper content from pandoc HTML, math pre-rendered server-side via katex.renderToString() (NOT client-side useEffect), then sanitized with DOMPurify
- KaTeX CSS imported for font rendering (npm package, not CDN)
- Sticky sidebar TOC generated from h2/h3 headings (collapse to hamburger on mobile)
- PDF download button (fixed position)
- Previous/Next paper navigation
- Per-page OG meta tags via generateMetadata()
- Themed code blocks and theorem environments matching the domain

**app/globals.css**: Generated theme CSS variables + Tailwind base + custom paper content styles (theorem blocks, code blocks, math display, tables) using the topic-driven palette

**public/**: Copy papers/pdf/*.pdf, images/*.png, docs/papers/*.html content

## STEP 3 — Data and Config

- Create papers.json manifest listing all papers with metadata (slug, title, part, abstract, pages, hasCode, category)
- Install DOMPurify: `npm install isomorphic-dompurify`
- Configure next.config.js with: output: 'export', images: { unoptimized: true }

## Quality Requirements
- Fully responsive and readable on mobile (no horizontal scroll)
- Papers must render math correctly via KaTeX
- Dark theme throughout — NEVER use white/light backgrounds
- Fast loading (static export, no client-side data fetching)
- Professional research aesthetic — the design must feel UNIQUE to this research domain, not like a generic template
- Each project's website should be visually distinguishable from other projects
```

### Step 6c — OG Image Generation

Spawn `og-image-generator` agent (can run in parallel with website-builder):

**Agent prompt:**
```
Generate Open Graph images (1200x630) for each research paper.

Project root: $PROJECT_PATH/$PROJECT
Papers: [list topics]

First, read the theme from `$PROJECT_PATH/$PROJECT/website/theme.json` to get the background color.

For each paper with a cover image in images/$TOPIC.png, run this Bash command:

    mkdir -p $PROJECT_PATH/$PROJECT/website/public/og
    sips -z 630 1200 "$PROJECT_PATH/$PROJECT/images/$TOPIC.png" --out "$PROJECT_PATH/$PROJECT/website/public/og/$TOPIC.png" 2>/dev/null

If sips produces poor results (aspect ratio), create a composite using the theme background color (read --bg from theme.json):

    BG_COLOR=$(python3 -c "import json; print(json.load(open('$PROJECT_PATH/$PROJECT/website/theme.json'))['colors']['bg'])")
    convert -size 1200x630 "xc:$BG_COLOR" "$PROJECT_PATH/$PROJECT/images/$TOPIC.png" -gravity center -resize 500x600 -composite "$PROJECT_PATH/$PROJECT/website/public/og/$TOPIC.png"

Also create a default og-image.png for the landing page using the first paper's cover.
```

### Step 6d — Codex Website Review (MANDATORY — do NOT skip)

This step is REQUIRED. After the website is built and BEFORE deploying to Vercel, invoke `codex:rescue` skill:

```
Review the Next.js research website at $PROJECT_PATH/$PROJECT/website/ for:
- HTML readability issues (semantic HTML, heading hierarchy, ARIA labels)
- Layout bugs (overflow, z-index conflicts, flex/grid issues)
- Design errors (contrast ratios, font sizes, spacing inconsistencies)
- Mobile responsiveness (touch targets, viewport issues, text readability)
- Broken links or missing assets
- KaTeX math rendering: check that math is pre-rendered server-side (katex.renderToString), NOT client-side (useEffect). Check for raw LaTeX in the static HTML output.
- Sidebar TOC: verify active section tracking uses scroll position (last heading above viewport), NOT IntersectionObserver with narrow rootMargin. Active item must highlight correctly when scrolling through long sections.
- Scroll behavior: check all scroll-dependent features work in static export (no JS on first load for SSG)
- React hydration: verify paper content uses ref callback with node.innerHTML to avoid KaTeX HTML hydration mismatches. Do NOT use React's built-in HTML insertion — it mangles KaTeX spans.
- OG meta tags: verify metadataBase is set in root layout (required for absolute OG URLs). Check that every paper page has og:image, og:url, og:title, og:description AND twitter:card + twitter:images in generateMetadata(). Homepage must have its own OG image too. Missing metadataBase = broken social previews on Facebook/LinkedIn/Twitter.
- After build, grep static HTML in out/ for og:image and twitter:card tags — every paper page must have them with absolute URLs.
- Performance issues (large bundles, unoptimized images)
List all issues with file paths and line numbers.
```

Fix all Codex-identified issues. Maximum 2 fix iterations. Log the number of issues found and fixed.

### Step 6e — Vercel Deployment

Run these Bash commands:

    cd $PROJECT_PATH/$PROJECT/website
    npm run build
    npx vercel --prod --yes 2>&1 | tee /tmp/vercel-deploy.log

**MANDATORY — Extract, validate, and persist the Vercel URL:**

The Vercel CLI output contains the production URL. **NEVER guess or construct the URL from the project name** — Vercel assigns its own subdomain which rarely matches.

Extract and save to disk with this single command block:

    VERCEL_URL=$(grep -oE 'https://[a-zA-Z0-9._-]+\.vercel\.app' /tmp/vercel-deploy.log | tail -1)
    echo "$VERCEL_URL" > $PROJECT_PATH/$PROJECT/.vercel-url
    echo "Extracted URL: $VERCEL_URL"

**GATE CHECK — Validate before proceeding:**

    URL=$(cat $PROJECT_PATH/$PROJECT/.vercel-url)
    echo "$URL" | grep -qE '^https://[a-zA-Z0-9._-]+\.vercel\.app$' && echo "URL OK: $URL" || echo "URL INVALID: $URL"
    echo "$URL" | grep -q '\.xn--' && echo "FAIL: punycode detected" || echo "PASS: no punycode"
    curl -sI "$URL" | head -1

The URL must:
1. End in `.vercel.app` (plain ASCII, no punycode like `.xn--`)
2. Be a valid HTTPS URL with no trailing special characters
3. Return `HTTP/2 200` or `HTTP/2 308` from curl

If validation fails, re-extract from the deploy log. NEVER send a punycode URL to Slack.

**CRITICAL: From this point forward, ALWAYS read the URL from `.vercel-url` file — NEVER construct it from the project name, NEVER type it from memory.** Every Slack message or social post that includes the Vercel URL must first run: `cat $PROJECT_PATH/$PROJECT/.vercel-url`

**MANDATORY — Website checkpoint before proceeding:**
- [ ] Step 6a: docs/papers/*.html exist for all papers
- [ ] Step 6b: website/ builds without errors (`npm run build` succeeds)
- [ ] Step 6c: website/public/og/*.png exist for all papers
- [ ] Step 6d: Codex website review completed, issues fixed
- [ ] Step 6e: Vercel deployment succeeded, $VERCEL_URL captured

**MANDATORY — Slack notification with Vercel URL** using `mcp__claude_ai_Slack__slack_send_message` to `$SLACK_CHANNEL`.

Before composing the message, read the URL from disk:

    cat $PROJECT_PATH/$PROJECT/.vercel-url

Use ONLY the value read from that file. Do NOT type a URL from memory or construct one from the project name.

```
Website deployed
URL: [value from .vercel-url file]
Papers: [count] HTML pages
OG images: [count]
Codex review: [issues found] → [issues fixed]
```

---

## Phase 7 — Social Posts

**Skip if `$SKIP_SOCIAL` is true.**

Spawn `social-posts` agent (foreground):

**Agent prompt:**
```
Generate social media posts for each research paper in the project.

Project root: $PROJECT_PATH/$PROJECT
Papers: [list all topics + synthesis with titles]
GitHub URL: https://github.com/$GITHUB_ORG/$PROJECT

IMPORTANT: Read the Vercel URL from disk by running: cat $PROJECT_PATH/$PROJECT/.vercel-url
Use ONLY the value from that file in all posts. NEVER guess or construct the URL from the project name — Vercel assigns its own subdomain.

For EACH paper, generate posts for 4 platforms. Save each to posts/$PLATFORM/$TOPIC.md

### Twitter/X (posts/twitter/$TOPIC.md)
- 280 character limit per tweet
- Hook-first: lead with the most surprising insight
- Thread format if needed (tweet 1/N)
- Include link to Vercel paper page
- 3-5 relevant hashtags
- Academic but accessible tone

### LinkedIn (posts/linkedin/$TOPIC.md)
- Professional, structured paragraphs
- Lead with problem statement
- 3-4 paragraphs: problem, approach, key finding, implications
- Include paper link and GitHub link
- Relevant hashtags at end

### Facebook (posts/facebook/$TOPIC.md)
- PLAIN TEXT ONLY — no markdown, no **bold**, no *italic*, no # headers
- Use emojis for visual structure
- Use line breaks (blank lines) to separate sections
- Use ALL CAPS sparingly for emphasis
- Structure: hook -> problem -> insight -> why it matters -> link -> hashtags
- Hashtags on their own line at the end
- Accessible to science-curious audience, not academic

### Bluesky (posts/bluesky/$TOPIC.md)
- 300 character limit
- Concise, punchy
- Link to paper
- 2-3 hashtags

Each post file should have YAML frontmatter with fields: platform, topic, title, status (draft).
```

---

## Phase 8 — Finalize

### Step 8a — Generate README.md (MANDATORY — do NOT skip)

Write `$PROJECT_PATH/$PROJECT/README.md` BEFORE committing or creating the GitHub repo. The README MUST exist before Step 8b.

Contents:
- Project title and description
- Architecture diagram (ASCII)
- Paper table (title, pages, category, links to Vercel pages and PDFs)
- Tech stack (LaTeX, Haskell, Next.js, Vercel)
- How to build locally
- Author info (from env vars)
- Links to Vercel site and individual papers
- Link to GitHub repo

Verify it exists: `test -f $PROJECT_PATH/$PROJECT/README.md && echo "OK" || echo "MISSING"`

### Step 8b — Git Commit and Push

**MANDATORY — Pre-commit verification.** Before committing, check that ALL generated artifacts are present and will be tracked:

    cd $PROJECT_PATH/$PROJECT
    # Remove any nested .gitignore that would exclude generated files
    find . -path ./.git -prune -o -name '.gitignore' -print
    # Check for untracked files that should be included
    git status -u

**MANDATORY — Verify PDFs are current (not stale from pre-fix compilation):**

    echo "=== PDF FRESHNESS CHECK ==="
    cd $PROJECT_PATH/$PROJECT
    for tex in papers/latex/*.tex; do
      name=$(basename "$tex" .tex)
      if test -f "papers/pdf/$name.pdf"; then
        if test "papers/pdf/$name.pdf" -nt "$tex"; then
          echo "PASS: $name.pdf is current"
        else
          echo "STALE: $name.pdf is older than $name.tex — RECOMPILING"
          cd papers/latex && pdflatex -interaction=nonstopmode "$name.tex" && pdflatex -interaction=nonstopmode "$name.tex" && cp "$name.pdf" ../pdf/ && cd $PROJECT_PATH/$PROJECT
        fi
      else
        echo "MISSING: $name.pdf — COMPILING"
        cd papers/latex && pdflatex -interaction=nonstopmode "$name.tex" && pdflatex -interaction=nonstopmode "$name.tex" && cp "$name.pdf" ../pdf/ && cd $PROJECT_PATH/$PROJECT
      fi
    done

Verify these directories have content:
- [ ] `papers/latex/*.tex` — LaTeX source files
- [ ] `papers/pdf/*.pdf` — compiled PDFs (verified current above)
- [ ] `reviews/*.md` — peer review output (round files + final canonical reviews)
- [ ] `src/*/` — Haskell source (if math present)
- [ ] `images/*.png` — cover images
- [ ] `docs/papers/*.html` — pandoc HTML conversions
- [ ] `website/` — full Next.js project (including package.json, package-lock.json, app/, public/, next.config.js)
- [ ] `website/public/og/*.png` — OG images
- [ ] `website/public/pdf/*.pdf` — PDF copies for download
- [ ] `website/public/images/*.png` — image copies
- [ ] `posts/` — social media posts (twitter/, linkedin/, facebook/, bluesky/)
- [ ] `README.md` — project README
- [ ] `.knowledge-base.md` — knowledge base

If website/.gitignore excludes node_modules/ that is correct. But if it excludes other generated files (like .next/ build output), that is also correct since the static export goes to out/. Do NOT delete website/.gitignore — it is needed. But DO ensure package-lock.json, README.md, and all source files under website/ are staged.

Stage and commit ALL files:

    cd $PROJECT_PATH/$PROJECT
    git add -A
    git status  # Verify everything is staged — no untracked files should remain
    git commit -m "Initial research pipeline output: [topic count] papers + synthesis
    
    Papers: [list topics]
    Includes: LaTeX sources, PDFs, Haskell proofs, HTML conversion, Next.js website, social posts"

**After committing, run `git status` again. If ANY untracked or unstaged files remain, stage and commit them in a follow-up commit. Zero files should be left behind.**

### Step 8c — Create GitHub Repo

First, read the Vercel URL from disk (do NOT guess it):

    VERCEL_URL=$(cat $PROJECT_PATH/$PROJECT/.vercel-url 2>/dev/null || echo "")

Then create the repo:

    gh repo create $GITHUB_ORG/$PROJECT --public \
      --description "Research papers: [brief description based on perspective and topics]" \
      --homepage "$VERCEL_URL"
    git remote add origin "https://github.com/$GITHUB_ORG/$PROJECT.git"
    git push -u origin main

### Step 8d — Final Slack Summary

**Before composing the message, read the Vercel URL from disk:**

    cat $PROJECT_PATH/$PROJECT/.vercel-url

Use ONLY the value from that file. NEVER construct, guess, or type the URL from memory.

Send to `$SLACK_CHANNEL` via `mcp__claude_ai_Slack__slack_send_message`:

```
Research Pipeline Complete

Project: $PROJECT
Topics: [comma-separated list]
Papers: [count] research papers + 1 synthesis
Haskell: [compiled/skipped] ([module count] modules)
Website: [value from .vercel-url file]
GitHub: https://github.com/$GITHUB_ORG/$PROJECT
Social Posts: [count] posts across 4 platforms

All papers peer-reviewed by Gemini 3.1 Pro and format-checked by Codex.
```

---

## Error Handling

- **Fix loops**: All review/fix cycles are bounded to **2 iterations maximum**. If issues persist after 2 rounds, log them and continue.
- **Missing tools**: If `gemini` CLI is not available, skip peer review and note it. If `pdflatex` is not available, skip PDF compilation. If `vercel` is not available, skip deployment.
- **Compilation failures**: If LaTeX or Haskell won't compile after 3 attempts, save the error log and continue with remaining topics.
- **Slack failures**: If Slack notification fails, log the error but don't block the pipeline.

## Agent Spawning Rules

- **Foreground agents** (need results before continuing): knowledge-base-builder, synthesis-agent, website-builder
- **Parallel agents** (independent work): research-workers (all topics), haskell-verifiers (all topics), og-image-generator
- **Background agents** (can overlap with other work): social-posts (if Vercel URL is already known)
- Always send parallel agents in a **single message with multiple Agent tool calls**
