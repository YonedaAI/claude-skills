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

1. Read pandoc HTML from file (server component or build step)
2. Call `renderMath(html)` — converts LaTeX delimiters to KaTeX HTML spans
3. Pass the HTML string to a client component that inserts it via ref callback

**CRITICAL: Do NOT use `dangerouslySetInnerHTML`.** React's hydration mangles KaTeX HTML (attribute mismatches, reordered spans), breaking math rendering and TOC scroll. Instead:

```tsx
// PaperContent.tsx — client component
'use client';
import { useCallback } from 'react';

export function PaperContent({ html }: { html: string }) {
  const contentRef = useCallback((node: HTMLDivElement | null) => {
    if (node) node.innerHTML = html;
  }, [html]);
  return <div ref={contentRef} className="paper-content" />;
}
```

This bypasses React reconciliation entirely. The HTML is our own pandoc + KaTeX output — DOMPurify is not needed for our own static build data.

TOC scroll spy must use `document.getElementById()` to find headings (they're in the real DOM but not React's virtual DOM).

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

## OG Meta Tags — Social Sharing Requirements

Social platforms (Facebook, LinkedIn, Twitter/X, Bluesky) require ABSOLUTE URLs for OG images. Next.js generates relative paths by default, which break previews.

### Required: `metadataBase` in Root Layout

```typescript
// app/layout.tsx — MUST set metadataBase
// Use Vercel's automatic env var — no hardcoded URLs or file reads
const siteUrl = process.env.VERCEL_PROJECT_PRODUCTION_URL
  ? `https://${process.env.VERCEL_PROJECT_PRODUCTION_URL}`
  : process.env.NEXT_PUBLIC_SITE_URL || 'http://localhost:3000';

export const metadata: Metadata = {
  metadataBase: new URL(siteUrl),
  openGraph: {
    type: 'website',
    siteName: 'Project Title',
    images: [{ url: '/images/og/og-image.png', width: 1200, height: 630 }],
  },
  twitter: {
    card: 'summary_large_image',
    images: ['/images/og/og-image.png'],
  },
};
```

### Required: Per-Paper OG + Twitter in `generateMetadata()`

```typescript
// app/papers/[slug]/page.tsx
export async function generateMetadata({ params }): Promise<Metadata> {
  const paper = papers.find(p => p.slug === params.slug);
  return {
    title: paper.title,
    description: paper.abstract,
    openGraph: {
      title: paper.title,
      description: paper.abstract,
      type: 'article',
      url: `/papers/${paper.slug}`,
      images: [{ url: `/images/og/${paper.slug}.png`, width: 1200, height: 630 }],
    },
    twitter: {
      card: 'summary_large_image',
      title: paper.title,
      description: paper.abstract,
      images: [`/images/og/${paper.slug}.png`],
    },
  };
}
```

### Common OG Failures

| Problem | Cause | Fix |
|---------|-------|-----|
| Facebook shows no image | Relative OG URL | Add `metadataBase` in root layout |
| Twitter shows plain link | Missing `twitter:card` tag | Add `twitter: { card: 'summary_large_image' }` |
| Homepage has no preview | No OG in page.tsx | Add explicit OG metadata to landing page |
| Paper previews wrong image | Missing per-page `generateMetadata` | Add OG image per paper page |
| OG image 404 | Image not copied to public/ | Verify `public/images/og/*.png` before build |

### Post-Build Verification

After `npm run build`, check the static HTML output:

```bash
for html in out/papers/*/index.html; do
  echo "=== $(basename $(dirname $html)) ==="
  grep -o 'property="og:image"[^>]*' "$html" | head -1
  grep -o 'name="twitter:card"[^>]*' "$html" | head -1
done
# Every page must have og:image with absolute URL (https://...)
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
npx vercel project add "$VERCEL_PROJECT" 2>/dev/null || true
npx vercel link --yes --project "$VERCEL_PROJECT"
# New projects: framework None + SSO protection — PATCH before deploying (see SKILL.md Step 6e)
curl -sS -X PATCH "https://api.vercel.com/v9/projects/${VERCEL_PROJECT_ID}?teamId=${VERCEL_ORG_ID}" \
  -H "Authorization: Bearer $VERCEL_TOKEN" -H "Content-Type: application/json" \
  -d '{"framework":"nextjs","ssoProtection":null}'
npx vercel pull --yes --environment=production
npx vercel build --prod
npx vercel deploy --prebuilt --prod 2>&1 | tee /tmp/vercel-deploy.log
# Clean alias: https://<project>.vercel.app — extract the URL from the log, never guess it
```
