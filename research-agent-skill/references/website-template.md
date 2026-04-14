# Website Template — Next.js 14 Research Site

## Design System — Dynamic Topic-Driven Theming

The website theme is NOT static. It is generated dynamically by the website-builder agent based on the research topics and perspective. The agent writes a `theme.json` file that defines all colors, fonts, and visual effects.

### Required CSS Variable Tokens

The theme MUST define all of these tokens in `app/globals.css`:

```css
:root {
  /* Generated dynamically from research domain — these are EXAMPLES only */
  --bg:               /* dark background, always dark */
  --surface:          /* card/panel background, slightly lighter */
  --surface-hover:    /* hover state for surfaces */
  --accent:           /* primary accent — domain-driven */
  --accent-hover:     /* lighter accent for hover */
  --accent-glow:      /* accent at ~15% opacity */
  --accent-secondary: /* complementary accent */
  --text:             /* primary text — high contrast on dark */
  --text-muted:       /* secondary text */
  --text-dim:         /* tertiary/disabled text */
  --border:           /* subtle borders */
  --code-bg:          /* code block background */
  --success:          /* status color */
  --warning:          /* status color */
}
```

### Domain-to-Palette Reference

| Research Domain | Suggested Palette Direction |
|----------------|---------------------------|
| Physics / Quantum | Deep blues (#0d1b2a), electric indigo, particle-cyan glows |
| Mathematics / Category Theory | Rich purple (#2d1b69), geometric magenta |
| Biology / Neuroscience | Dark forest (#0a1f0a), organic emerald, bioluminescent teal |
| Computer Science / AI | Near-black (#0a0e14), electric cyan (#00d4ff), circuit-green |
| Chemistry | Deep navy (#0f0a1a), molecular amber (#f59e0b) |
| Cosmology / Gravity | Void black (#050510), nebula purple, stellar gold |
| Economics / Social | Charcoal (#1a1a1a), warm copper (#b87333), earth tones |

### theme.json Format

Written by website-builder agent to `website/theme.json`:

```json
{
  "name": "descriptive-theme-name",
  "domain": "detected research domain",
  "colors": {
    "bg": "#...",
    "surface": "#...",
    "accent": "#...",
    "accentSecondary": "#...",
    "text": "#...",
    "textMuted": "#...",
    "border": "#...",
    "codeBg": "#..."
  },
  "font": "Inter|Crimson Pro|Source Serif 4|...",
  "heroGradient": "linear-gradient(...)",
  "cardEffect": "glow|grow|slide|fade",
  "bgPattern": "description of SVG/CSS background pattern"
}
```

### Typography
- **Font**: Chosen by theme based on domain (serif for classical, sans for modern)
- **Headings**: Semi-bold, accent color for h2
- **Body**: 1.75 line-height for readability
- **Code**: JetBrains Mono or system monospace

### Breakpoints
- Mobile: < 640px (1 column, hamburger menu)
- Tablet: 640-1024px (2 columns)
- Desktop: > 1024px (3 columns, sidebar TOC)

## KaTeX Integration

### Pandoc Conversion (CRITICAL)

Use `--mathjax` flag (NOT `--katex`) when converting with pandoc:

    pandoc paper.tex --to html5 --mathjax --toc --number-sections -o paper.html

Why NOT `--katex`? The `--katex` flag inlines KaTeX HTML at conversion time, which breaks on complex expressions. Using `--mathjax` keeps math as LaTeX source in `\(...\)` and `\[...\]` delimiters that KaTeX renders at runtime.

### Next.js KaTeX Setup — Server-Side Pre-Rendering

Install as npm package:

    npm install katex

DO NOT use client-side rendering (`useEffect` + `renderMathInElement`). This fails on static export because there is no JS on first page load — users see raw LaTeX.

Instead, create `lib/render-math.ts` that uses `katex.renderToString()` at build time:

```typescript
import katex from 'katex';

// IMPORTANT: Custom macros must be extracted from each paper's \newcommand
// definitions in the LaTeX preamble. The render-math utility should:
// 1. Read all .tex files in papers/latex/
// 2. Parse \newcommand{\name}[args]{definition} lines
// 3. Convert to KaTeX macro format: '\\name': 'expansion'
// 4. Merge with the base macros below

const BASE_MACROS: Record<string, string> = {
  // LaTeX commands not natively in KaTeX
  '\\slashed': '\\not{#1}',
  '\\roman': '\\mathrm{#1}',
  // Common operator names
  '\\tr': '\\operatorname{tr}',
  '\\Tr': '\\operatorname{Tr}',
  '\\diag': '\\operatorname{diag}',
  '\\adj': '\\operatorname{adj}',
  '\\sgn': '\\operatorname{sgn}',
  '\\Hom': '\\operatorname{Hom}',
  '\\Mor': '\\operatorname{Mor}',
  '\\Ob': '\\operatorname{Ob}',
  '\\id': '\\operatorname{id}',
  '\\im': '\\operatorname{im}',
  '\\coker': '\\operatorname{coker}',
  '\\rank': '\\operatorname{rank}',
  '\\Lan': '\\operatorname{Lan}',
  '\\Ran': '\\operatorname{Ran}',
  '\\Nat': '\\operatorname{Nat}',
  '\\PSh': '\\operatorname{PSh}',
  // Dirac notation
  '\\bra': '\\langle#1|',
  '\\ket': '|#1\\rangle',
  '\\braket': '\\langle#1|#2\\rangle',
  '\\ketbra': '|#1\\rangle\\langle#2|',
  '\\expect': '\\langle#1\\rangle',
};

// Auto-extract custom macros from LaTeX preambles
function extractMacros(texFiles: string[]): Record<string, string> {
  const macros = { ...BASE_MACROS };
  for (const tex of texFiles) {
    const matches = tex.matchAll(
      /\\newcommand\{\\([a-zA-Z]+)\}(?:\[(\d+)\])?\{([^}]*(?:\{[^}]*\}[^}]*)*)\}/g
    );
    for (const m of matches) {
      const [, name, argCount, body] = m;
      // Convert LaTeX arg format (#1, #2) to KaTeX format
      macros['\\' + name] = body;
    }
  }
  return macros;
}

export function renderMath(html: string): string {
  // Display math: \[...\] and $$...$$
  html = html.replace(/\\\[([\s\S]*?)\\\]/g, (_, tex) =>
    katex.renderToString(tex.trim(), { displayMode: true, throwOnError: false, trust: true, macros: MACROS })
  );
  html = html.replace(/\$\$([\s\S]*?)\$\$/g, (_, tex) =>
    katex.renderToString(tex.trim(), { displayMode: true, throwOnError: false, trust: true, macros: MACROS })
  );
  // Inline math: \(...\) and $...$
  html = html.replace(/\\\(([\s\S]*?)\\\)/g, (_, tex) =>
    katex.renderToString(tex.trim(), { displayMode: false, throwOnError: false, trust: true, macros: MACROS })
  );
  html = html.replace(/(?<![\\$])\$(?!\$)([^\n]*?)(?<![\\$])\$/g, (_, tex) =>
    katex.renderToString(tex.trim(), { displayMode: false, throwOnError: false, trust: true, macros: MACROS })
  );
  return html;
}
```

### Render Flow

Correct order in the SERVER component (no client component needed):
1. Read pandoc HTML from file
2. Call `renderMath(html)` — converts LaTeX delimiters to KaTeX HTML spans
3. Sanitize with DOMPurify (ADD_TAGS: `['span', 'math', 'semantics', 'annotation']`, ADD_ATTR: `['xmlns', 'encoding', 'class', 'style', 'aria-hidden']`)
4. Pass to template — math is static HTML, no JS needed

Include KaTeX CSS in layout: `import 'katex/dist/katex.min.css'`

### Common Math Failures

| Problem | Symptom | Fix |
|---------|---------|-----|
| Raw `$$...$$` showing | Math not rendered | KaTeX auto-render not running — check component mount |
| `\slashed{D}` error | Red error text | Add macro: `'\\slashed': '\\not{#1}'` |
| `SU(2)_L` in prose | Subscript not rendered | Wrap in `\(SU(2)_L\)` during post-processing |
| `\mathbb{R}` blank | Missing glyph | KaTeX CSS not loaded |
| Aligned environments break | Misaligned rows | Use `\\\\` not `\\` in HTML |

### Macros for Unsupported Commands

Add these to the KaTeX `macros` config:
- `\slashed` → `\not{#1}`
- `\tr` → `\operatorname{tr}`
- `\Tr` → `\operatorname{Tr}`
- `\diag` → `\operatorname{diag}`
- `\adj` → `\operatorname{adj}`

### Sidebar TOC — Active Section Tracking

DO NOT use IntersectionObserver for TOC active state. It fails when headings scroll past the viewport.

Use a scroll listener that finds the last heading above viewport top:
- On scroll: iterate all heading elements, find the last one with `offsetTop <= window.scrollY + 100`
- Set that as the active TOC item
- Use `{ passive: true }` on the scroll listener for performance
- Set initial state on component mount

Style active item with theme accent color and left border:
```css
.toc-active {
  color: var(--accent);
  border-left: 2px solid var(--accent);
  background: var(--accent-glow);
}
```

### Post-Conversion Verification

After pandoc, scan for un-wrapped math:

    grep -P '(?<![\\\(\[])\\(mathcal|frac|sqrt|sum|int|partial|slashed|bar|hat)\{' docs/papers/*.html

Fix by wrapping in `\(...\)` for inline or `\[...\]` for display.

## Paper Content Styles

Style the pandoc HTML output with these selectors:

```css
/* Theorem blocks */
.paper-content .theorem,
.paper-content .definition,
.paper-content .lemma,
.paper-content .proposition {
  border-left: 3px solid var(--accent);
  padding: 1rem 1.5rem;
  margin: 1.5rem 0;
  background: var(--surface);
  border-radius: 0 8px 8px 0;
}

/* Code blocks */
.paper-content pre {
  background: var(--code-bg);
  border: 1px solid var(--border);
  border-radius: 8px;
  padding: 1rem;
  overflow-x: auto;
}

/* Tables */
.paper-content table {
  width: 100%;
  border-collapse: collapse;
  margin: 1.5rem 0;
}
.paper-content th, .paper-content td {
  border: 1px solid var(--border);
  padding: 0.75rem;
}
.paper-content th {
  background: var(--surface);
}

/* Math display */
.paper-content .math-display {
  overflow-x: auto;
  padding: 1rem 0;
}
```

## Sidebar TOC

Auto-generate from h2/h3 headings in the paper content:

```tsx
// Extract headings from HTML
const headings = cleanHtml.match(/<h[23][^>]*id="([^"]*)"[^>]*>(.*?)<\/h[23]>/g);

// Render as sticky sidebar (desktop) or hamburger menu (mobile)
```

## Static Export Configuration

```js
// next.config.js
module.exports = {
  output: 'export',
  images: { unoptimized: true },
  trailingSlash: true,
}
```

## papers.json Manifest

Generate this file during the pipeline to list all papers:

```json
[
  {
    "slug": "topic-name",
    "title": "Full Paper Title",
    "part": "Part I",
    "abstract": "First 300 characters of the abstract...",
    "pages": 25,
    "hasCode": true,
    "category": "quant-ph",
    "pdfPath": "/pdf/topic-name.pdf",
    "ogImage": "/og/topic-name.png"
  }
]
```

## Vercel Deployment

```bash
cd website
npm run build        # Generates static export in out/
npx vercel --prod --yes 2>&1 | tee /tmp/vercel-deploy.log
# Extract URL from output: grep for "Production:" or "https://"
```
