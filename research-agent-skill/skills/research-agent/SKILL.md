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
- `$GITHUB_ORG` — GitHub organization (default: `YonedaAI`)
- `$SLACK_CHANNEL` — Slack channel ID (from `$RESEARCH_SLACK_CHANNEL` env var or default `C0AK269AVSA`)
- `$SKIP_HASKELL`, `$SKIP_WEBSITE`, `$SKIP_SOCIAL` — boolean flags

## CRITICAL — Mandatory Steps (never skip these)

Every phase has a MANDATORY checkpoint. You MUST complete ALL of these — they are not optional:

1. **Gemini peer review** — Every paper (workers + synthesis) MUST be reviewed by `gemini -m gemini-3.1-pro`. The review MUST be saved to `reviews/`. Skipping this is a pipeline failure.
2. **Codex formatting check** — Every paper MUST be checked by `codex:rescue` after review fixes. Skipping this is a pipeline failure.
3. **Codex website review** — The website MUST be reviewed by `codex:rescue` BEFORE Vercel deployment (Step 6d). Skipping this is a pipeline failure.
4. **Slack per-topic notifications** — Send a Slack message after EACH worker completes, after synthesis completes, after Haskell verification completes, after website deployment, and a final summary. These are 5+ separate Slack messages minimum.
5. **Fix cycles** — After each review (Gemini or Codex), you MUST fix the identified issues before proceeding. Max 2 iterations per cycle.

If you present a plan to the user, the plan MUST explicitly list all 5 of the above as separate line items. Do not collapse them into a phase header.

---

## Author Block (used in all papers)

```
Matthew Long
The YonedaAI Collaboration
YonedaAI Research Collective
Chicago, IL
matthew@yonedaai.com · https://yonedaai.com
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
Matthew Long
The YonedaAI Collaboration, YonedaAI Research Collective
Chicago, IL
matthew@yonedaai.com · https://yonedaai.com

If the topic involves mathematics, also create Haskell modules in `src/$TOPIC/`:
- Main.hs with runnable demonstrations
- Supporting modules for key abstractions
- Each file must compile with GHC

### Stage 2 — Gemini Peer Review
Run peer review via Gemini CLI. Execute this Bash command:

    cat papers/latex/$TOPIC.tex | gemini -m gemini-3.1-pro -p "Peer review this research paper. Evaluate: mathematical correctness, clarity, completeness, logical structure, LaTeX quality. Output structured feedback with specific line-level suggestions organized by severity (critical, major, minor)."

Save the review output to `reviews/$TOPIC-review.md`.

### Stage 3 — Fix Review Issues
Read `reviews/$TOPIC-review.md` and revise `papers/latex/$TOPIC.tex` to address ALL critical and major feedback.
Also fix any Haskell code issues mentioned in the review.
Maximum 2 revision iterations.

### Stage 4 — Codex LaTeX Formatting Check
Use the Codex plugin to review LaTeX formatting:
Invoke the `codex:rescue` skill with prompt:
"Review papers/latex/$TOPIC.tex for LaTeX formatting issues: compilation errors, missing packages, broken references, inconsistent styling, overfull/underfull boxes, spacing problems. List all issues with line numbers and fixes."

Fix all issues identified by Codex. Maximum 2 fix iterations.

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
[ ] Stage 2: reviews/$TOPIC-review.md exists with Gemini output
[ ] Stage 3: Paper revised to address ALL critical/major review feedback
[ ] Stage 4: Codex formatting check run, issues fixed
[ ] Stage 5: GrokRxiv sidebar added to page 1
[ ] Stage 6: papers/pdf/$TOPIC.pdf exists and compiles cleanly
[ ] Stage 7: images/$TOPIC.png exists (300 DPI cover)

When complete, report: topic name, paper page count, whether Haskell code was created, PDF compilation status, number of review issues addressed, number of Codex issues fixed.
```

**MANDATORY — Slack notification per completed topic:**

After EACH worker completes (not after all — after EACH one), immediately send a Slack notification using `mcp__claude_ai_Slack__slack_send_message` to channel `$SLACK_CHANNEL`:

```
Research paper completed: $TOPIC
Pages: [count]
PDF: papers/pdf/$TOPIC.pdf
Haskell: [yes/no]
Gemini review: [issues found] → [issues fixed]
Codex check: [issues found] → [issues fixed]
Review file: reviews/$TOPIC-review.md
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

4. Run Gemini peer review (same as workers — gemini -m gemini-3.1-pro)
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
You are a Haskell verification agent.

Project root: $PROJECT_PATH/$PROJECT
Topic: $TOPIC
Source directory: src/$TOPIC/

1. Read all .hs files in src/$TOPIC/
2. Ensure Main.hs exists with a main function that demonstrates key abstractions
3. Compile with this Bash command:

       cd $PROJECT_PATH/$PROJECT && ghc -o src/$TOPIC/test src/$TOPIC/Main.hs src/$TOPIC/*.hs -isrc/$TOPIC 2>&1

4. If compilation fails, fix errors and recompile (max 3 iterations)
5. Run the compiled binary with this Bash command:

       src/$TOPIC/test
6. Verify output is meaningful (not empty, no runtime errors)
7. Invoke codex:rescue skill: "Review Haskell code in src/$TOPIC/ for: type safety issues, missing type signatures, incomplete pattern matches, code quality, idiomatic Haskell style. List all issues."
8. Fix Codex-identified issues (max 2 iterations)
9. Recompile and verify after fixes

Clean up compiled binaries: `rm -f src/$TOPIC/test src/$TOPIC/*.o src/$TOPIC/*.hi`
Report: compilation status, test output summary, issues fixed.
```

**MANDATORY — Haskell checkpoint before proceeding:**
- [ ] All src/$TOPIC/ directories compile with GHC without errors
- [ ] All Main.hs binaries produce non-empty, error-free output
- [ ] Codex review run on each module, issues fixed

**MANDATORY — Slack notification on Haskell verification completion** using `mcp__claude_ai_Slack__slack_send_message` to `$SLACK_CHANNEL`:
```
Haskell verification completed
Topics verified: [list]
Modules compiled: [count]
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
      pandoc "$tex" --to html5 --katex --toc --toc-depth=3 --number-sections --no-highlight --wrap=none -o "docs/papers/$name.html"
    done

If `scripts/latex2html.py` exists, prefer using it for better post-processing:

    python3 scripts/latex2html.py --latex-dir papers/latex --html-dir docs/papers --template scripts/paper-template.html --project-title "$PROJECT" --papers "topic:Title:Part N" ...

### Step 6b — Next.js Website

Spawn `website-builder` agent (foreground):

**Agent prompt:**
```
You are building a modern, mobile-ready research website.

Project root: $PROJECT_PATH/$PROJECT
Papers: [list all topics + synthesis with titles]
GitHub org: $GITHUB_ORG
Project name: $PROJECT

1. Create a Next.js 14 static site in website/. Run this Bash command:

       cd $PROJECT_PATH/$PROJECT && npx create-next-app@14 website --typescript --tailwind --app --no-src-dir --no-import-alias --use-npm

2. Build the site with these pages:

   **app/layout.tsx**: Root layout with:
   - Inter font from next/font
   - Dark theme (bg: #0a0a0f, surface: #12121a, accent: #6c5ce7, text: #e4e4ef)
   - Global OG meta tags
   - Navigation header

   **app/page.tsx**: Landing page with:
   - Project title and description
   - Paper cards grid (responsive: 1 col mobile, 2 col tablet, 3 col desktop)
   - Each card shows: cover image, title, part number, abstract excerpt
   - Links: "Read" (HTML), "PDF" (download), "Code" (GitHub src link)
   - Modern design: subtle gradients, card hover effects, clean typography

   **app/papers/[slug]/page.tsx**: Individual paper pages with:
   - Full paper content from pandoc HTML (sanitized with DOMPurify via isomorphic-dompurify)
   - KaTeX CSS + JS from CDN for math rendering
   - Sidebar table of contents (sticky, collapsible on mobile)
   - PDF download button
   - Navigation to prev/next paper
   - Per-page OG meta tags via generateMetadata()

   **app/globals.css**: Dark theme with CSS variables matching paper-template.html

   **public/**: Copy over papers/pdf/*.pdf, images/*.png, docs/papers/*.html content

3. Create papers.json manifest listing all papers with metadata

4. Install DOMPurify: `npm install isomorphic-dompurify`

5. Configure next.config.js with: output: 'export', images: { unoptimized: true }

The site must be:
- Fully responsive and readable on mobile
- Papers must render math correctly via KaTeX
- Dark theme throughout
- Fast loading (static export)
- Professional research aesthetic (not generic AI look)
```

### Step 6c — OG Image Generation

Spawn `og-image-generator` agent (can run in parallel with website-builder):

**Agent prompt:**
```
Generate Open Graph images (1200x630) for each research paper.

Project root: $PROJECT_PATH/$PROJECT
Papers: [list topics]

For each paper with a cover image in images/$TOPIC.png, run this Bash command:

    mkdir -p $PROJECT_PATH/$PROJECT/website/public/og
    sips -z 630 1200 "$PROJECT_PATH/$PROJECT/images/$TOPIC.png" --out "$PROJECT_PATH/$PROJECT/website/public/og/$TOPIC.png" 2>/dev/null

If sips produces poor results (aspect ratio), create a composite instead:

    convert -size 1200x630 xc:'#0a0a0f' "$PROJECT_PATH/$PROJECT/images/$TOPIC.png" -gravity center -resize 500x600 -composite "$PROJECT_PATH/$PROJECT/website/public/og/$TOPIC.png"

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
- KaTeX math rendering setup
- Performance issues (large bundles, unoptimized images)
List all issues with file paths and line numbers.
```

Fix all Codex-identified issues. Maximum 2 fix iterations. Log the number of issues found and fixed.

### Step 6e — Vercel Deployment

Run these Bash commands:

    cd $PROJECT_PATH/$PROJECT/website
    npm run build
    npx vercel --prod --yes 2>&1 | tee /tmp/vercel-deploy.log

Extract the deployment URL from the output. Store as `$VERCEL_URL`.

**MANDATORY — Website checkpoint before proceeding:**
- [ ] Step 6a: docs/papers/*.html exist for all papers
- [ ] Step 6b: website/ builds without errors (`npm run build` succeeds)
- [ ] Step 6c: website/public/og/*.png exist for all papers
- [ ] Step 6d: Codex website review completed, issues fixed
- [ ] Step 6e: Vercel deployment succeeded, $VERCEL_URL captured

**MANDATORY — Slack notification with Vercel URL** using `mcp__claude_ai_Slack__slack_send_message` to `$SLACK_CHANNEL`:
```
Website deployed
URL: $VERCEL_URL
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
Vercel URL: $VERCEL_URL (or "deployment pending" if not available)
GitHub URL: https://github.com/$GITHUB_ORG/$PROJECT

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

### Step 8a — Generate README.md

Write `$PROJECT_PATH/$PROJECT/README.md` with:
- Project title and description
- Architecture diagram (ASCII)
- Paper table (title, pages, category, links)
- Tech stack (LaTeX, Haskell, Next.js, Vercel)
- How to build locally
- Author info
- Links to Vercel site and individual papers

### Step 8b — Git Commit and Push

**MANDATORY — Pre-commit verification.** Before committing, check that ALL generated artifacts are present and will be tracked:

    cd $PROJECT_PATH/$PROJECT
    # Remove any nested .gitignore that would exclude generated files
    find . -path ./.git -prune -o -name '.gitignore' -print
    # Check for untracked files that should be included
    git status -u

Verify these directories have content:
- [ ] `papers/latex/*.tex` — LaTeX source files
- [ ] `papers/pdf/*.pdf` — compiled PDFs
- [ ] `reviews/*.md` — peer review output
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
    Includes: LaTeX sources, PDFs, Haskell proofs, HTML conversion, Next.js website, social posts
    
    Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"

**After committing, run `git status` again. If ANY untracked or unstaged files remain, stage and commit them in a follow-up commit. Zero files should be left behind.**

### Step 8c — Create GitHub Repo

Run these Bash commands:

    gh repo create $GITHUB_ORG/$PROJECT --public \
      --description "Research papers: [brief description based on perspective and topics]" \
      --homepage "$VERCEL_URL"
    git remote add origin "https://github.com/$GITHUB_ORG/$PROJECT.git"
    git push -u origin main

### Step 8d — Final Slack Summary

Send to `$SLACK_CHANNEL` via `mcp__claude_ai_Slack__slack_send_message`:

```
Research Pipeline Complete

Project: $PROJECT
Topics: [comma-separated list]
Papers: [count] research papers + 1 synthesis
Haskell: [compiled/skipped] ([module count] modules)
Website: $VERCEL_URL
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
