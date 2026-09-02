# Paper format: arXiv-style article

Every paper looks like a conventional arXiv preprint: 11pt article, one column, a restrained title block, a one-paragraph abstract, numbered sections with plain headings, indented paragraphs, booktabs tables, and a small bibliography. Nothing on the page should look like large print, a book, or a slide.

## Document class and preamble (use exactly this skeleton)

```latex
\documentclass[11pt,letterpaper]{article}

\usepackage[T1]{fontenc}
\usepackage{lmodern}
\usepackage{microtype}
\usepackage[top=1in,bottom=1in,left=1.25in,right=1.25in]{geometry}  % 6in measure, about 90 characters per line
\linespread{1.0}
\setlength{\parskip}{0pt}          % conventional article: indent, no vertical gap
\setlength{\parindent}{1.5em}

\usepackage{amsmath,amssymb,amsthm}
\usepackage{graphicx}
\usepackage{xcolor}
\usepackage{tikz}                  % and tikz-cd when commutative diagrams are used
\usepackage{booktabs,tabularx,array,longtable}
\newcolumntype{L}[1]{>{\raggedright\arraybackslash}p{#1}}
\usepackage{listings}
\lstset{basicstyle=\ttfamily\footnotesize,breaklines=true,columns=fullflexible,frame=single,framesep=4pt,showstringspaces=false,captionpos=b}
\usepackage[hidelinks]{hyperref}
\usepackage{cleveref}

\newtheorem{theorem}{Theorem}[section]
\newtheorem{proposition}[theorem]{Proposition}
\newtheorem{lemma}[theorem]{Lemma}
\newtheorem{corollary}[theorem]{Corollary}
\theoremstyle{definition}
\newtheorem{definition}[theorem]{Definition}
\theoremstyle{remark}
\newtheorem{remark}[theorem]{Remark}
```

Do not change the font size, the margins, or the paragraph settings. Do not add `parskip`. Do not redefine `abstract`, `section`, or `maketitle`.

## Title block

```latex
\title{Short Title in Title Case\\[4pt]
  {\normalsize Part N of \emph{Series Title in Title Case}}}
\author{$RESEARCH_AUTHOR_NAME\\
  \small $RESEARCH_COLLABORATION, $RESEARCH_INSTITUTION\\
  \small $RESEARCH_LOCATION\\
  \small \texttt{$RESEARCH_AUTHOR_EMAIL}}
\date{Month YYYY}
```

Title rules: a noun phrase of two to six words, in Title Case, that a working scholar would put on a paper ("Agent Teams", "The Anatomy of Agentic Engineering", "Plan, Act, Verify, Repeat"). No colon followed by a list, no "what X, what Y, and what Z", no question, no subtitle that summarizes the argument. The series line is the only subtitle.

## Abstract

Use the standard `abstract` environment. One paragraph, 150 to 250 words, no citations, no lists, no line breaks. It states the question, the approach, the main findings with their numbers where the paper has them, and the limitation that matters most. It does not narrate the paper's sections and it does not contain definitions.

## Headings

Sections and subsections are numbered and written in sentence case as plain noun phrases of one to seven words that name the subject: "Definitions", "Prior art", "The failure catalogue", "Randomized trials", "Limitations". Not allowed: clauses ("The mechanism argument, and what is wrong with it"), tails (", stated once", ", named and left"), verdicts in the heading ("Benchmarks cannot carry the argument"), counts ("Three consequences this Part does not develop"), questions ("Does a team earn its cost?"), and "what/why/where" constructions ("What a plan buys", "Why self-review does not count"). If the heading needs a verb to be understood, the heading is wrong.

## Paragraphs and prose

Follow `style-standard.md`. Paragraphs are indented with no extra vertical space; a paragraph is one claim and its support; consequential claims get short sentences.

## Tables and figures

Booktabs rules only (`\toprule`, `\midrule`, `\bottomrule`), no vertical rules. Cells contain complete phrases or short sentences a reader can say aloud; telegraphic fragments with semicolons ("diffuse; no single origin") are not allowed. Choose column widths so that ordinary words do not hyphenate; use `\small` and `tabularx` `X` columns before shrinking further; if a table cannot fit without fragments, it is prose or an appendix. Captions are one or two complete sentences placed above tables and below figures. At most eight figures and tables per paper.

## Bibliography

`thebibliography` in `\small`, entries in the order cited or alphabetical (one rule per paper, applied to every entry), page and date ranges with hyphens (the humanizer rule forbids en dashes), arXiv identifiers and DOIs given as plain text.

## GrokRxiv sidebar (page 1 only, restrained)

```latex
\usepackage{everypage}
\definecolor{grokgray}{RGB}{110,110,110}
\AddEverypageHook{%
  \ifnum\value{page}=1
    \begin{tikzpicture}[remember picture, overlay]
      \node[rotate=90, anchor=south, font=\footnotesize\sffamily\color{grokgray}, inner sep=0pt]
        at ([xshift=30pt, yshift=0.5\paperheight]current page.south west)
        {GrokRxiv:<DOI_SLUG>\quad [\,<CATEGORY>\,]\quad <DATE>};
    \end{tikzpicture}
  \fi
}
```

| Placeholder | Format | Example |
|-------------|--------|---------|
| `<DOI_SLUG>` | `YYYY.MM.<kebab-case-topic>` | `2026.09.agent-teams` |
| `<CATEGORY>` | arXiv category | `cs.SE`, `cs.MA`, `cs.AI`, `math.CT` |
| `<DATE>` | `DD Mon YYYY` | `02 Sep 2026` |

## Compilation

```bash
rm -f *.aux *.log *.out *.toc
pdflatex -interaction=nonstopmode $TOPIC.tex
pdflatex -interaction=nonstopmode $TOPIC.tex
pdflatex -interaction=nonstopmode $TOPIC.tex
grep -E '^!|Undefined control|undefined|Overfull' $TOPIC.log
```

## Format check (run before the final compile; every line must print OK)

```bash
T=papers/latex/$TOPIC.tex
grep -q '\\documentclass\[11pt,letterpaper\]{article}' "$T" && echo "OK class" || echo "FAIL class: use 11pt letterpaper"
grep -q 'left=1.25in,right=1.25in' "$T" && echo "OK margins" || echo "FAIL margins"
! grep -qE '\\usepackage(\[[^]]*\])?\{parskip\}|\\setlength\{\\parskip\}\{[1-9]' "$T" && echo "OK no parskip" || echo "FAIL parskip: no parskip package, no nonzero \\parskip"
w=$(awk '/\\begin\{abstract\}/{f=1;next} /\\end\{abstract\}/{f=0} f' "$T" | wc -w); [ "$w" -ge 150 ] && [ "$w" -le 250 ] && echo "OK abstract $w words" || echo "FAIL abstract $w words (150 to 250)"
p=$(awk '/\\begin\{abstract\}/{f=1;next} /\\end\{abstract\}/{f=0} f' "$T" | awk 'BEGIN{RS=""} END{print NR}'); [ "$p" -le 1 ] && echo "OK abstract one paragraph" || echo "FAIL abstract has $p paragraphs"
! awk '/\\begin\{abstract\}/{f=1;next} /\\end\{abstract\}/{f=0} f' "$T" | grep -q '\\cite' && echo "OK abstract no citations" || echo "FAIL abstract cites"
grep -nE '\\(sub)*section\*?\{[^}]*(, (and|stated|named)|\?|what |why |where |nobody|does not|is not|that is the|this (Part|paper)|cannot|worth )' "$T" | grep -v '^\s*%' && echo "FAIL heading style (lines above)" || echo "OK headings"
grep -nE '\\(sub)*section\*?\{(One|Two|Three|Four|Five|Six) ' "$T" && echo "FAIL counted heading" || echo "OK no counted headings"
grep -nE '\\title\{[^}]*(: | and what )' "$T" && echo "FAIL title has colon list" || echo "OK title"
grep -nE '&[^&\\]*; [^&\\]*&' "$T" | grep -vE '^\s*%' | head -3 && echo "CHECK table cells with semicolon fragments (lines above)" || echo "OK table cells"
grep -nE 'font=\\(Large|large|LARGE)' "$T" && echo "FAIL sidebar font too large" || echo "OK sidebar"
```

## Quality checklist
- [ ] Skeleton preamble used unchanged; 11pt; 6in measure
- [ ] Title is a short Title Case noun phrase; series line is the only subtitle
- [ ] Abstract: one paragraph, 150 to 250 words, no citations
- [ ] Every heading is a plain noun phrase in sentence case
- [ ] Every table cell is a complete phrase; no hyphenated fragments in narrow columns
- [ ] No agent activity, reviewer verdicts, confidence labels, or process language in the paper
- [ ] No undefined references or citations; no overfull boxes above 2pt
- [ ] Sidebar present on page 1 in footnotesize
- [ ] 20 to 35 pages at 11pt
