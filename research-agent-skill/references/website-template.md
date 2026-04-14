# Website Template — Next.js 14 Research Site

## Design System

### Color Palette (from paper-template.html)

```css
:root {
  --bg: #0a0a0f;
  --surface: #12121a;
  --surface-hover: #1a1a2e;
  --accent: #6c5ce7;
  --accent-hover: #7c6cf7;
  --accent-glow: rgba(108, 92, 231, 0.15);
  --text: #e4e4ef;
  --text-muted: #8888a0;
  --text-dim: #555570;
  --border: #2a2a3e;
  --code-bg: #0d0d14;
  --success: #2ecc71;
  --warning: #f39c12;
}
```

### Typography
- **Font**: Inter (via `next/font/google`)
- **Headings**: Semi-bold, accent color for h2
- **Body**: 1.75 line-height for readability
- **Code**: JetBrains Mono or system monospace

### Breakpoints
- Mobile: < 640px (1 column, hamburger menu)
- Tablet: 640-1024px (2 columns)
- Desktop: > 1024px (3 columns, sidebar TOC)

## KaTeX Integration

Include in paper pages only (not landing page):

```html
<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/katex@0.16.11/dist/katex.min.css">
<script defer src="https://cdn.jsdelivr.net/npm/katex@0.16.11/dist/katex.min.js"></script>
<script defer src="https://cdn.jsdelivr.net/npm/katex@0.16.11/dist/contrib/auto-render.min.js"
  onload="renderMathInElement(document.body, {
    delimiters: [
      {left: '$$', right: '$$', display: true},
      {left: '$', right: '$', display: false},
      {left: '\\[', right: '\\]', display: true},
      {left: '\\(', right: '\\)', display: false}
    ]
  })"></script>
```

In Next.js, add these via `<Script>` component in the paper page layout.

## Paper Content Rendering

Papers are converted from LaTeX to HTML via pandoc. The HTML body is then sanitized and rendered:

```tsx
import DOMPurify from 'isomorphic-dompurify';

// Read the pandoc-generated HTML content
const rawHtml = fs.readFileSync(`docs/papers/${slug}.html`, 'utf-8');

// Sanitize before rendering
const cleanHtml = DOMPurify.sanitize(rawHtml, {
  ADD_TAGS: ['math', 'semantics', 'annotation'],
  ADD_ATTR: ['xmlns', 'encoding'],
});
```

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
