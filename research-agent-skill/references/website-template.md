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

### Next.js KaTeX Setup

Install as npm package (NOT CDN — doesn't work with Next.js hydration):

    npm install katex

Create a client component that:
1. Imports `katex/dist/katex.min.css` for font/styling
2. Imports `katex/dist/contrib/auto-render` for delimiter processing
3. Calls `renderMathInElement()` in `useEffect` on the paper content container ref
4. Configures delimiters: `$$...$$`, `\[...\]` (display), `\(...\)`, `$...$` (inline)
5. Sets `throwOnError: false`, `trust: true`
6. Adds macros for unsupported commands (see table below)

### Render Flow

Correct order: sanitize HTML with DOMPurify → insert into DOM → run KaTeX auto-render on the container ref. KaTeX must run AFTER the HTML is in the DOM.

DOMPurify config must allow math-related tags:
- ADD_TAGS: `['math', 'semantics', 'annotation', 'span']`
- ADD_ATTR: `['xmlns', 'encoding', 'class', 'style']`

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
