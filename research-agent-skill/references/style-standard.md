# Academic style standard (mandatory for every paper, the synthesis, the README, and website copy in every research-agent run)

The target is academic prose with intellectual authority, not "academic-sounding" prose. Good academic writing makes difficult ideas precise without making straightforward ideas difficult. Density, qualification, and abstraction are not substitutes for clarity.

## The standard

Write in rigorous scholarly prose suitable for a serious technical monograph or peer-reviewed paper. Prioritize precision, clarity, and argumentative flow over density or formality for its own sake. Each paragraph should advance one identifiable claim and support it with evidence, reasoning, or citation. State important findings directly before qualifying them. Use technical terminology when it increases precision, but prefer ordinary language when it expresses the same idea exactly. Vary sentence length and structure. Use short sentences for consequential claims. Avoid excessive nominalization, nested subordinate clauses, bureaucratic phrasing, artificial transitions, repetitive signposting, and symmetrical "First... Second... Third..." constructions unless the enumeration genuinely aids comprehension.

Do not write sentences whose complexity comes primarily from packing multiple independent findings, methodological qualifications, citations, and conclusions together. Separate them.

Avoid generic academic filler such as "It is important to note," "This Part seeks to," "the aforementioned," "the quantity that would settle," "under the documented search strategy," or "Three findings follow from the evidence" when the findings can simply be stated.

Sound like a scholar explaining something important to another scholar, not like a model imitating the statistical surface features of academic writing.

Complexity must come from the subject matter, not from the prose. If the subject is evaluator bias, bounded agent loops, formal verification, or distributed systems, the ideas may be difficult; the prose should do everything possible to make them easier to reason about.

## Two worked examples

Weak:

"Third, the quantity that would settle the central economic question, namely verification minutes measured against authoring minutes for the same task at matched quality, is not measured by any source located under the documented search strategy."

Strong:

"The central economic question remains unanswered: is verification cheaper than authoring at equivalent quality? None of the sources in our review measures authoring and verification time on the same tasks under matched quality criteria."

Weak:

"Second, iteration bounds are published widely and the distribution of rounds actually consumed is published nowhere..."

Strong:

"Iteration limits are widely reported, but actual iteration counts are not. Across the six bounded loops examined here, every implementation specifies a maximum number of rounds. None reports the empirical distribution of rounds required in practice."

The strong versions are more scholarly, not less: the proposition and its evidentiary basis are immediately identifiable. Think good physics or computer science paper, not a model pretending to be a nineteenth-century journal editor.

## Absence wording (replaces the earlier brief wording)

When no documented case or measurement exists, say so plainly and once: "We found no documented case of X in the sources reviewed (cutoff <research cutoff date>)." or "None of the sources we located reports X." Do not write "no qualifying evidence was identified under the documented search strategy as of the cutoff."

## Paragraph test (apply while editing)

1. What is this paragraph's one claim? If you cannot name it in a sentence, split or cut the paragraph.
2. Is the claim stated before its qualifications?
3. Does every sentence carry one finding, one qualification, or one inference, not several?
4. Could a shorter ordinary word replace a technical one without loss? If so, replace it.
5. Does the paragraph open with a signpost ("First", "In this section", "Having established") that adds nothing? Cut it.
6. Are the citations attached to the sentence they support, not gathered at the end of a compound sentence?

## Filler and signposting grep (run from the project root; fix every hit by rewriting)

```bash
cd "$PROJECT_ROOT"
fail=0
for tex in papers/latex/*.tex; do
  echo "=== $tex ==="
  grep -niE 'it is important to note|it is worth noting|it should be noted|this (part|paper|section) (seeks|aims|attempts) to|the aforementioned|aforementioned|the quantity that would settle|under the documented search strategy|as of the cutoff|findings follow from the evidence|in what follows|having established|it follows that|in this section,? we|the remainder of this|we now turn to|note that,? |namely,? |in other words,? |that is to say|it is (clear|evident|apparent) that|of note|with respect to|in terms of|in the context of|a number of|the fact that' "$tex" | grep -vE '^[[:space:]]*%|\\(cite|bibitem|url|href)' && { echo "HIT: filler or signposting"; fail=1; }
  grep -nE '^\s*(First|Second|Third|Fourth|Fifth|Finally),' "$tex" | grep -vE '^[[:space:]]*%' && { echo "HIT: enumerated signposting (keep only if the enumeration aids comprehension; otherwise rewrite)"; fail=1; }
done
[ "$fail" = 0 ] && echo "STYLE GREP: CLEAN" || echo "STYLE GREP: rewrite the hits above"
```

"namely" and "note that" hits are allowed only where the sentence reads naturally without them being removed; the default is to remove them. The enumerated-signposting check is a prompt to judge, not an absolute ban: a genuine list of three parallel conditions may keep its numbering.

## What a style pass may and may not change

May change: sentence and paragraph structure, word choice, transitions, signposting, the order of a claim and its qualifications, the splitting of compound sentences, the placement of citations within a sentence.

May not change: the meaning of any claim; any number, denominator, or window; any citation or bibliography entry; the operational content, numbering, or label of any Definition or Proposition; the number, order, or numbering of sections, figures, tables, and listings (sibling Parts cite them by number); the series title; the sidebar; the abstract's factual content. If a sentence that appears verbatim in the paper's claim ledger, when one exists is rewritten, update the ledger row to the new wording.
