# Paper Format Requirements

## Document Structure

All papers use arxiv-style LaTeX format with minimum 20 pages.

### Document Class and Packages
```latex
\documentclass[12pt]{article}

% Core math
\usepackage{amsmath, amssymb, amsthm}

% Diagrams
\usepackage{tikz-cd}
\usepackage{tikz}

% References
\usepackage{hyperref}
\usepackage{cleveref}

% Graphics
\usepackage{graphicx}

% Page layout
\usepackage[margin=1in]{geometry}

% GrokRxiv sidebar
\usepackage{everypage}
\usepackage{xcolor}
```

### Theorem Environments
```latex
\newtheorem{theorem}{Theorem}[section]
\newtheorem{proposition}[theorem]{Proposition}
\newtheorem{lemma}[theorem]{Lemma}
\newtheorem{corollary}[theorem]{Corollary}
\theoremstyle{definition}
\newtheorem{definition}[theorem]{Definition}
\theoremstyle{remark}
\newtheorem{remark}[theorem]{Remark}
```

### Required Sections
1. **Abstract** — concise summary of contributions
2. **Introduction** — motivation, context, outline
3. **Mathematical Framework** — formal definitions, notation
4. **[Topic-specific sections]** — core content (3-5 sections)
5. **Results** — main theorems and proofs
6. **Discussion** — implications, limitations, connections
7. **Conclusion** — summary and future work
8. **References** — bibliography

### Author Block
```latex
\author{Matthew Long \\
\textit{The YonedaAI Collaboration} \\
\textit{YonedaAI Research Collective} \\
Chicago, IL \\
\texttt{matthew@yonedaai.com} $\cdot$ \url{https://yonedaai.com}}
```

## GrokRxiv DOI Sidebar

Add to preamble BEFORE `\begin{document}`:

```latex
\definecolor{grokgray}{RGB}{110,110,110}
\AddEverypageHook{%
  \ifnum\value{page}=1
    \begin{tikzpicture}[remember picture, overlay]
      \node[
        rotate=90,
        anchor=south,
        font=\Large\sffamily\bfseries\color{grokgray},
        inner sep=0pt
      ] at ([xshift=38pt, yshift=0.52\paperheight]current page.south west)
      {GrokRxiv:<DOI_SLUG>\quad
       [\,<CATEGORY>\,]\quad
       <DATE>};
    \end{tikzpicture}
  \fi
}
```

### Substitution Rules

| Placeholder | Format | Example |
|-------------|--------|---------|
| `<DOI_SLUG>` | `YYYY.MM.<kebab-case-topic>` | `2026.04.quantum-gravity` |
| `<CATEGORY>` | arXiv-style category | `quant-ph`, `hep-th`, `math.CT`, `cs.AI` |
| `<DATE>` | `DD Mon YYYY` | `14 Apr 2026` |

## Compilation

```bash
# Compile twice for references and TOC
pdflatex -interaction=nonstopmode $TOPIC.tex
pdflatex -interaction=nonstopmode $TOPIC.tex

# Clean artifacts (keep only .tex and .pdf)
rm -f *.aux *.log *.toc *.out *.bbl *.blg *.nav *.snm *.vrb *.fls *.fdb_latexmk *.synctex.gz
```

## Quality Checklist
- [ ] Minimum 20 pages
- [ ] All theorems have proofs or proof sketches
- [ ] Formal definitions before first use
- [ ] Consistent notation throughout
- [ ] No undefined references or citations
- [ ] GrokRxiv sidebar present on page 1
- [ ] Compiles without errors
- [ ] No overfull/underfull box warnings (or minimal)
