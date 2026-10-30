<!-- research-agent:begin — appended by install.sh; safe to re-run -->
## research-agent

For research-paper / research-pipeline requests, run the `research-agent` skill:
read `skills/research-agent/SKILL.md`, which points at the shared body
`core/SKILL.body.md` and the Codex overlay `skills/research-agent/CODEX.md`.

Host-model drafting: the orchestrating model (Codex) authors every artifact.
**reviewers are never the main model drafting.** AGY reviews science, Claude reviews
code — Codex NEVER reviews itself. Reviewer names and swap rules:
`settings/research-agent.settings.json`, mirrored in `core/references/harness-matrix.md`.
<!-- research-agent:end -->
