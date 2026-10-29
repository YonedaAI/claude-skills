// research-agent — MiMoCode Dynamic Workflow
//
// MiMo drafts every artifact. AGY (Gemini) and Codex review. This script only
// sequences and gates; every timestamp, external CLI and network call lives
// inside agent() bash prompts, because the workflow sandbox has no Date/fetch/process.
//
// Stage prompts live in prompts/*.md and reference docs in references/*.md. Both
// are copied into the workspace before this runs (see skills/research-agent/SKILL.md).

export const meta = {
  name: "research-agent",
  description:
    "Multi-agent research pipeline: MiMo drafts parallel arXiv-style papers, AGY and Codex review, optional Haskell verification, website, social posts, git+GitHub publish.",
  whenToUse:
    "when the user asks to research topics, generate research papers, run a research pipeline, create academic papers with peer review, or invokes /research-agent",
  phases: [
    { title: "Setup" },
    { title: "Knowledge Base" },
    { title: "Workers (parallel)" },
    { title: "Synthesis" },
    { title: "Haskell Verify" },
    { title: "Website" },
    { title: "Social" },
    { title: "Publish" },
  ],
  model: "xiaomi/mimo-v2.6-pro",
  permissions: [
    { permission: "bash", patterns: ["git *"], reason: "commit and inspect the research repo" },
    {
      permission: "bash",
      patterns: ["pdflatex *", "pandoc *", "ghc *", "cabal *", "stack *", "pdftoppm *"],
      reason: "compile LaTeX and Haskell deliverables and cover images",
    },
    { permission: "bash", patterns: ["vercel *", "gh *", "curl *"], reason: "deploy the site and open the PR" },
    { permission: "external_directory", patterns: ["**"], reason: "the pipeline writes a project workspace" },
  ],
}

// ---- Models. Measured on the token-plan-sgp endpoint: ONLY pro and flash are served.
//      mimo-v2.6-pro-ultraspeed returns 400 "Not supported model". Never reference it.
const MIMO_PRO = "xiaomi/mimo-v2.6-pro" // papers, synthesis, math, Haskell/Lean
const MIMO_FLASH = "xiaomi/mimo-v2.6-flash" // KB, website, social, validation, images

// ---- Arg normalisation -------------------------------------------------------
function str(v, dflt) {
  if (v === undefined || v === null) return dflt
  return String(v)
}
function bool(v, dflt) {
  if (v === undefined || v === null) return dflt
  if (typeof v === "boolean") return v
  const s = String(v).toLowerCase()
  return !(s === "0" || s === "false" || s === "no" || s === "off")
}
function list(v) {
  if (v === undefined || v === null) return []
  if (Array.isArray(v)) return v.map((x) => String(x).trim()).filter(Boolean)
  return String(v)
    .split(",")
    .map((x) => x.trim())
    .filter(Boolean)
}

// ---- Gate helper: an agent() that resolves null must fail the phase -----------
function require_(value, label) {
  if (value === null || value === undefined) {
    log(`FAIL: ${label} returned no result`)
    throw new Error(`gate failed: ${label}`)
  }
  return value
}

export default async function () {
  const a = typeof args === "object" && args !== null ? args : {}

  const topics = list(a.topics)
  const perspective = str(a.perspective, "")
  const project = str(a.project, topics.length ? topics[0].replace(/[^A-Za-z0-9]+/g, "-").toLowerCase() : "research")
  const githubOrg = str(a.githubOrg, "YonedaAI")
  const slackChannel = str(a.slackChannel, "C0AK269AVSA")
  const noHaskell = bool(a.noHaskell, false)
  const noWebsite = bool(a.noWebsite, false)
  const noSocial = bool(a.noSocial, false)
  const humanReadable = bool(a.humanReadable, false)
  const codeAudit = bool(a.codeAudit, false)
  const bibGate = bool(a.bibGate, false)
  const planCritique = bool(a.planCritique, false)

  if (!topics.length) {
    log("FAIL: no topics supplied")
    return { ok: false, reason: "no topics supplied" }
  }

  // Shared preamble handed to every agent so nothing has to be re-derived.
  const ctx = [
    `PROJECT="${project}"`,
    `PERSPECTIVE=${JSON.stringify(perspective)}`,
    `GITHUB_ORG="${githubOrg}"`,
    `SLACK_CHANNEL="${slackChannel}"`,
    `HUMAN_READABLE=${humanReadable ? "ON" : "OFF"}`,
    `CODE_AUDIT=${codeAudit ? "ON" : "OFF"}`,
    `BIB_GATE=${bibGate ? "ON" : "OFF"}`,
    `PLAN_CRITIQUE=${planCritique ? "ON" : "OFF"}`,
    ``,
    `Workspace root is the current directory. The stage prompt is at prompts/`,
    `and the reference docs at references/ — read them before acting.`,
  ].join("\n")

  // ===================== Phase 1 — Setup =====================
  phase("Setup")
  const setup = require_(
    await agent(
      `${ctx}

You are the pipeline setup agent. Do ONLY this, then report.

1. Create the project directory tree:
   papers/latex  papers/pdf  reviews  src  images  docs/papers  website  posts/twitter
   posts/linkedin  posts/facebook  posts/bluesky  team  sources
2. Initialise a git repo here if one does not exist and set local user.name/user.email from
   the git-author resolution in prompts/pipeline-validator.md. Local config only — never
   touch the user's global git config.
3. Write .gitignore exactly as specified in prompts/pipeline-validator.md (LaTeX aux,
   node_modules, website build output, .review.lock/, and sources/ preprints).
4. Write sources/README.md stating source preprints are not redistributable and must be linked.
5. REVIEWER SANITY TESTS — mandatory, run both and print the raw output:
   - AGY: resolve the shim exactly as prompts/research-worker.md does (it must land on
     /Users/mlong/.local/bin/agy-review-shim, and the plain \`gemini\` CLI is deprecated and
     must never be used). Pipe the string "reply with exactly: PONG" through it and echo the
     result and the exit code.
   - Codex: resolve \`codex\` to an absolute path the same way, then run
     \`codex exec -m gpt-6.1-sol -c 'model_reasoning_effort="low"' -s read-only --skip-git-repo-check "reply with exactly: PONG"\`
     and echo the result and the exit code.
   If either test does not return usable output, you MUST fail with a clear reason. Do not
   write a stub, do not continue, do not fake the result.
6. Also run the AGY stderr log check described in prompts/research-worker.md if output is empty.

Report JSON only:
{"agy":"PONG-or-error","agyExit":0,"codex":"PONG-or-error","codexExit":0,"dirs":"created","gitignore":"written"}`,
      {
        agentType: "general",
        model: MIMO_PRO,
        label: "setup",
        timeoutMs: 300000,
        schema: {
          type: "object",
          properties: {
            agy: { type: "string" },
            agyExit: { type: "number" },
            codex: { type: "string" },
            codexExit: { type: "number" },
            dirs: { type: "string" },
            gitignore: { type: "string" },
          },
          required: ["agy", "agyExit", "codex", "codexExit"],
        },
      },
    ),
    "setup",
  )

  if (setup.agyExit !== 0 || !/PONG/i.test(setup.agy)) {
    log(`FAIL: AGY reviewer not reachable (exit=${setup.agyExit}, out=${setup.agy})`)
    return { ok: false, reason: "AGY sanity test failed", setup }
  }
  if (setup.codexExit !== 0 || !/PONG/i.test(setup.codex)) {
    log(`FAIL: Codex reviewer not reachable (exit=${setup.codexExit}, out=${setup.codex})`)
    return { ok: false, reason: "Codex sanity test failed", setup }
  }
  log("reviewer sanity: AGY and Codex both reachable")

  // ===================== Phase 2 — Knowledge Base =====================
  phase("Knowledge Base")
  require_(
    await agent(
      `${ctx}

You are the knowledge-base builder. Read prompts/knowledge-base-builder.md and follow it exactly.

TOPICS:
${topics.map((t) => `- ${t}`).join("\n")}

Produce .knowledge-base.md in the workspace root: structured notes per topic (claims,
definitions, open questions, candidate references). Use xiaomi/mimo-v2.6-flash-class work —
fast and voluminous — but do NOT invent citations. Anything you cannot verify is marked
UNVERIFIED. Report JSON only:
{"file":".knowledge-base.md","topics":${topics.length},"unverified":0}`,
      {
        agentType: "general",
        model: MIMO_FLASH,
        label: "knowledge-base",
        timeoutMs: 600000,
        schema: {
          type: "object",
          properties: {
            file: { type: "string" },
            topics: { type: "number" },
            unverified: { type: "number" },
          },
          required: ["file", "topics"],
        },
      },
    ),
    "knowledge-base",
  )

  // ===================== Phase 3 — Workers (parallel) =====================
  phase("Workers (parallel)")
  const workerResults = await parallel(
    topics.map((topic) => async () => {
      const r = await agent(
        `${ctx}

You are the research worker for ONE topic.

TOPIC: ${topic}

Read prompts/research-worker.md and execute EVERY stage in order, without skipping,
combining or reordering. That prompt is the authoritative procedure. Key invariants:

- MiMo drafts the paper. AGY (the agy-review-shim) is the ONLY scientific reviewer and
  Codex is the ONLY formatting/code reviewer. Never self-review. Never write a SKIPPED stub.
- Wrap every single reviewer call in the .review.lock mutex exactly as the prompt shows.
- AGY review-fix loop: max 3 rounds, until VERDICT is ACCEPT or MINOR REVISIONS.
- Codex review-fix loop: max 2 fix passes (3 invocations), until VERDICT is PASS.
- ${codeAudit ? "CODE_AUDIT: ON — run the code evidence appendix audit." : "CODE_AUDIT: OFF."}
- ${humanReadable ? "HUMAN_READABLE: ON — run the humanizer grep checks before the compile." : "HUMAN_READABLE: OFF."}
- ${bibGate ? "BIB_GATE: ON — resolve every bibliography entry before the final compile." : "BIB_GATE: OFF."}
- Paper geometry is \\usepackage[margin=1in]{geometry} (one-inch margins). Never 12pt.
- Add the GrokRxiv sidebar only AFTER the scientific review loop completes.
- Recompile the PDF after ALL fixes so the PDF matches the final .tex.

Report JSON only:
{
  "topic": ${JSON.stringify(topic)},
  "tex": "papers/latex/<topic>.tex",
  "pdf": "papers/pdf/<topic>.pdf",
  "pages": 0,
  "haskell": "yes|no|skipped",
  "reviewVerdict": "ACCEPT|MINOR REVISIONS|MAJOR REVISIONS|REJECT",
  "reviewRounds": 0,
  "codexVerdict": "PASS|NEEDS_FIX",
  "codexRounds": 0,
  "status": "ok|failed"
}`,
        {
          agentType: "general",
          model: MIMO_PRO,
          label: `worker-${topic.slice(0, 32)}`,
          timeoutMs: 3600000,
          schema: {
            type: "object",
            properties: {
              topic: { type: "string" },
              tex: { type: "string" },
              pdf: { type: "string" },
              pages: { type: "number" },
              haskell: { type: "string" },
              reviewVerdict: { type: "string" },
              reviewRounds: { type: "number" },
              codexVerdict: { type: "string" },
              codexRounds: { type: "number" },
              status: { type: "string" },
            },
            required: ["topic", "tex", "reviewVerdict", "reviewRounds", "status"],
          },
        },
      )
      if (r === null) {
        log(`FAIL: worker for "${topic}" returned no result`)
        return { topic, status: "failed", reviewVerdict: "NONE", reviewRounds: 0 }
      }
      return r
    }),
  )

  // Fail-closed gate over every worker.
  const bad = workerResults.filter((r) => !r || r.status !== "ok" || r.reviewRounds < 1)
  if (bad.length) {
    log(`FAIL: ${bad.length} worker(s) did not iterate a real review: ${JSON.stringify(bad)}`)
    return { ok: false, reason: "worker review gate failed", workers: workerResults }
  }
  const verdicts = workerResults.map((r) => `${r.topic}: ${r.reviewVerdict} (${r.reviewRounds} rounds)`)
  log(`workers complete — ${verdicts.join("; ")}`)

  // ===================== Phase 4 — Synthesis =====================
  phase("Synthesis")
  const synth = require_(
    await agent(
      `${ctx}

You are the synthesis agent. Read prompts/synthesis-agent.md and follow it exactly.

TOPICS AND WORKER OUTCOMES:
${workerResults.map((r) => `- ${r.topic}: ${r.reviewVerdict}, ${r.reviewRounds} rounds`).join("\n")}

Unify all papers into one coherent synthesis at papers/latex/synthesis.tex. MiMo writes it;
AGY reviews it and Codex checks its formatting — same review-fix loops and the same
.review.lock mutex as prompts/research-worker.md. Never self-review. Max 3 AGY rounds.

Report JSON only:
{"tex":"papers/latex/synthesis.tex","pdf":"papers/pdf/synthesis.pdf",
 "reviewVerdict":"ACCEPT|MINOR REVISIONS|MAJOR REVISIONS|REJECT","reviewRounds":0,"status":"ok|failed"}`,
      {
        agentType: "general",
        model: MIMO_PRO,
        label: "synthesis",
        timeoutMs: 2700000,
        schema: {
          type: "object",
          properties: {
            tex: { type: "string" },
            pdf: { type: "string" },
            reviewVerdict: { type: "string" },
            reviewRounds: { type: "number" },
            status: { type: "string" },
          },
          required: ["tex", "reviewVerdict", "reviewRounds", "status"],
        },
      },
    ),
    "synthesis",
  )
  if (synth.status !== "ok" || synth.reviewRounds < 1) {
    log(`FAIL: synthesis did not iterate a real review: ${JSON.stringify(synth)}`)
    return { ok: false, reason: "synthesis review gate failed", synthesis: synth, workers: workerResults }
  }

  // ===================== Phase 5 — Haskell verification =====================
  let haskell = { status: "skipped" }
  if (!noHaskell) {
    phase("Haskell Verify")
    haskell = require_(
      await agent(
        `${ctx}

You are the Haskell/Lean verifier. Read prompts/haskell-verifier.md and follow it exactly.

Compile every module under src/ with ghc/cabal/stack. Fix type errors. Then run the Codex
Haskell review exactly as the prompt shows (under the .review.lock mutex, max 2 fix passes).
You may NOT review your own code.

Report JSON only:
{"modules":0,"compiled":true,"codexVerdict":"PASS|NEEDS_FIX","codexRounds":0,"status":"ok|failed"}`,
        {
          agentType: "general",
          model: MIMO_PRO,
          label: "haskell",
          timeoutMs: 2700000,
          schema: {
            type: "object",
            properties: {
              modules: { type: "number" },
              compiled: { type: "boolean" },
              codexVerdict: { type: "string" },
              codexRounds: { type: "number" },
              status: { type: "string" },
            },
            required: ["modules", "compiled", "status"],
          },
        },
      ),
      "haskell",
    )
    if (haskell.status !== "ok") {
      log(`FAIL: Haskell verification failed: ${JSON.stringify(haskell)}`)
      return { ok: false, reason: "haskell gate failed", haskell, workers: workerResults }
    }
  } else {
    log("Haskell verification skipped by flag")
  }

  // ===================== Phase 6 — Website =====================
  let website = { status: "skipped" }
  if (!noWebsite) {
    phase("Website")
    website = require_(
      await agent(
        `${ctx}

You are the website builder. Read prompts/website-builder.md and follow it exactly.

Convert every paper to HTML with pandoc into docs/papers/, build the Next.js site under
website/, generate the designed OG cards and run the OG validation gate, then run the Codex
website review (mandatory, before deploy) and only then deploy with vercel.

Report JSON only:
{"docs":0,"site":"website/","ogValid":true,"codexVerdict":"PASS|NEEDS_FIX",
 "vercelUrl":"https://...","status":"ok|failed"}`,
        {
          agentType: "general",
          model: MIMO_FLASH,
          label: "website",
          timeoutMs: 3600000,
          schema: {
            type: "object",
            properties: {
              docs: { type: "number" },
              site: { type: "string" },
              ogValid: { type: "boolean" },
              codexVerdict: { type: "string" },
              vercelUrl: { type: "string" },
              status: { type: "string" },
            },
            required: ["docs", "site", "status"],
          },
        },
      ),
      "website",
    )
    if (website.status !== "ok") {
      log(`FAIL: website build failed: ${JSON.stringify(website)}`)
      return { ok: false, reason: "website gate failed", website, workers: workerResults }
    }
  } else {
    log("website skipped by flag")
  }

  // ===================== Phase 7 — Social =====================
  let social = { status: "skipped" }
  if (!noSocial) {
    phase("Social")
    social = require_(
      await agent(
        `${ctx}

You are the social-posts agent. Read prompts/social-posts.md and follow it exactly.

Write platform-specific posts under posts/twitter/, posts/linkedin/, posts/facebook/ and
posts/bluesky/. No process language, no reviewer verdicts, no confidence labels.

Report JSON only:
{"files":0,"platforms":["twitter","linkedin","facebook","bluesky"],"status":"ok|failed"}`,
        {
          agentType: "general",
          model: MIMO_FLASH,
          label: "social",
          timeoutMs: 900000,
          schema: {
            type: "object",
            properties: {
              files: { type: "number" },
              platforms: { type: "array", items: { type: "string" } },
              status: { type: "string" },
            },
            required: ["files", "status"],
          },
        },
      ),
      "social",
    )
    if (social.status !== "ok") {
      log(`FAIL: social posts failed: ${JSON.stringify(social)}`)
      return { ok: false, reason: "social gate failed", social, workers: workerResults }
    }
  } else {
    log("social skipped by flag")
  }

  // ===================== Phase 8 — Publish =====================
  phase("Publish")
  const publish = require_(
    await agent(
      `${ctx}

You are the publish agent. Read prompts/pipeline-validator.md and follow it exactly.

1. Run the FULL pipeline validator checklist (artifact presence, OG image dimensions/std-dev,
   .vercel-url integrity, review files substantive). A FAIL means fix and re-validate.
2. Write README.md for the project.
3. \`git add -A\` and commit. Use the git-author resolution in prompts/pipeline-validator.md
   and never the user's global git config.
4. Open a GitHub PR under the org above with \`gh\` if available.
5. Send the Slack summary. The Slack tool name and markdown rules are in
   prompts/pipeline-validator.md — run slack_lint_msg on the message first. Send to
   ${slackChannel}. A bare URL or angle-bracket URL is a lint failure.

Report JSON only:
{"validator":"PASS|FAIL","commits":0,"pr":"https://...","slack":"sent|skipped","status":"ok|failed"}`,
      {
        agentType: "general",
        model: MIMO_FLASH,
        label: "publish",
        timeoutMs: 1800000,
        schema: {
          type: "object",
          properties: {
            validator: { type: "string" },
            commits: { type: "number" },
            pr: { type: "string" },
            slack: { type: "string" },
            status: { type: "string" },
          },
          required: ["validator", "status"],
        },
      },
    ),
    "publish",
  )
  if (publish.status !== "ok" || publish.validator !== "PASS") {
    log(`FAIL: publish/validation gate failed: ${JSON.stringify(publish)}`)
    return {
      ok: false,
      reason: "publish gate failed",
      publish,
      workers: workerResults,
      synthesis: synth,
    }
  }

  log(`research-agent complete — ${topics.length} topic(s), all gates PASS`)
  return {
    ok: true,
    project,
    topics,
    workers: workerResults,
    synthesis: synth,
    haskell,
    website,
    social,
    publish,
    drafter: MIMO_PRO,
    reviewers: ["AGY (Gemini 4 Argon High)", "Codex (gpt-6.1-sol)"],
  }
}
