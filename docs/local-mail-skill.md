# Plan — `local-mailer` plugin

## Context

The research-agent pipeline (just shipped v0.7.8) currently announces completion only via Slack — `mcp__claude_ai_Slack__slack_send_message` at the end of Phase 8 (research-agent-skill/skills/research-agent/SKILL.md:1070). The user wants the same notifications delivered as **email** to a real inbox (mlong168@gmail.com), driven from the local machine, so pipeline outcomes (GitHub repo + Vercel URL) land in their mailbox without needing Slack open.

Decisions already settled with the user:
- **Transport:** Nodemailer over Gmail SMTPS (smtp.gmail.com:465) using a Gmail app password.
- **Surface:** A standalone plugin `local-mailer` exposing a generic `/mail` slash command **and** a research-agent integration that emails the final pipeline summary.
- **Trigger:** Final summary only (Phase 8). Body-only — no attachments, just inline links to Vercel/GitHub.

## Recommended approach

Ship a new top-level plugin `local-mailer/` next to `app-store-publish/` and `research-agent-skill/`. Mirror their layout (markdown commands + skill) and add a small `scripts/send-mail.js` Nodemailer CLI. Then patch one location in research-agent to call out to it when `RESEARCH_MAIL_TO` is set.

### New plugin layout — `/Users/mlong/Documents/Development/claude-skills/local-mailer/`

```
local-mailer/
├── .claude-plugin/plugin.json     # name/version/author — mirror research-agent format
├── README.md                       # setup: Gmail app password, env file, PATH symlink
├── package.json                    # single dep: nodemailer ^6
├── commands/
│   └── mail.md                     # /mail send | /mail test | /mail config
├── skills/local-mailer/
│   └── SKILL.md                    # how agents invoke send-local-mail
├── scripts/
│   ├── send-mail.js                # Nodemailer CLI (the only executable code)
│   └── install.sh                  # symlinks send-local-mail into ~/.local/bin
└── templates/
    └── env.example                 # SMTP_USER/SMTP_PASS/MAIL_FROM/MAIL_TO_DEFAULT
```

### Files to create

**`local-mailer/.claude-plugin/plugin.json`** — copy the field set used at research-agent-skill/.claude-plugin/plugin.json:1-11 (name, version 0.1.0, description, author, license MIT, keywords `["mail","smtp","nodemailer","notifications"]`).

**`local-mailer/scripts/send-mail.js`** — Node CLI, ~80 lines. Responsibilities:
- Load env vars from `process.env`; if `SMTP_USER`/`SMTP_PASS` unset, source `~/.local-mailer.env` (single stable path; survives plugin reinstalls — unlike `${CLAUDE_PLUGIN_ROOT}/.env` which lives in plugin cache).
- Parse flags: `--to`, `--subject`, `--text`, `--html` (optional), `--from` (optional override). Also accept JSON on stdin when no flags given (`{"to","subject","text","html"}`) for piping from bash heredocs.
- `nodemailer.createTransport({ host: SMTP_HOST||"smtp.gmail.com", port: SMTP_PORT||465, secure: true, auth: { user: SMTP_USER, pass: SMTP_PASS } })`.
- Print `OK <messageId>` on success, exit 0; print `ERR <reason>` to stderr, exit 1 on any failure (auth, missing flags, network). Never crash a calling pipeline silently.

**`local-mailer/scripts/install.sh`** — `mkdir -p ~/.local/bin && ln -sf "$(realpath scripts/send-mail.js)" ~/.local/bin/send-local-mail && chmod +x scripts/send-mail.js`. README tells the user to run it once after install and to ensure `~/.local/bin` is on `PATH`.

**`local-mailer/commands/mail.md`** — slash command with three subcommands. Frontmatter follows the conventions in app-store-publish commands. Subcommands:
- `/mail send` — interactively prompt (via AskUserQuestion) for to/subject/body, then call `send-local-mail`.
- `/mail test` — send a fixed test message to `MAIL_TO_DEFAULT`; useful for verifying creds.
- `/mail config` — print current env (with password masked) and config file path.

**`local-mailer/skills/local-mailer/SKILL.md`** — short trigger doc. Description: "Use when the user asks to email someone, set up email notifications, or send mail from a script. Wraps nodemailer over Gmail SMTPS." Body: command examples and a note that the binary is `send-local-mail` once installed.

**`local-mailer/templates/env.example`** — mirror app-store-publish/templates/env.example.template format:
```
SMTP_HOST=smtp.gmail.com
SMTP_PORT=465
SMTP_USER=mlong168@gmail.com
SMTP_PASS=               # 16-char Gmail app password (App passwords → Mail)
MAIL_FROM="Claude Pipeline <mlong168@gmail.com>"
MAIL_TO_DEFAULT=mlong168@gmail.com
```
README instructs `cp templates/env.example ~/.local-mailer.env && chmod 600 ~/.local-mailer.env`.

**`local-mailer/package.json`** — single runtime dep `"nodemailer": "^6.9"`. No build step; script is plain Node 18+. README's setup line: `(cd local-mailer && npm install && bash scripts/install.sh)`.

### File to modify

**`research-agent-skill/skills/research-agent/SKILL.md`** — add **Step 8d.4 — Optional email send** immediately after the existing line 1070 (`Step 8d.3 — Send to $SLACK_CHANNEL …`). The new step:
1. Compose `$EMAIL_BODY` as a plain-text version of `$SLACK_MSG` (same facts, no `<…>` URL wrapping, no `*bold*`). Build it in the same heredoc block where `$SLACK_MSG` is composed (around line 1023–1039) so both stay in sync.
2. Gate: `if command -v send-local-mail >/dev/null 2>&1 && [ -n "$RESEARCH_MAIL_TO" ]; then …`. Both conditions must hold — the plugin not being installed must NOT fail the pipeline, and silent default-on must not surprise users who haven't set up creds.
3. Call: `send-local-mail --to "$RESEARCH_MAIL_TO" --subject "Research Pipeline Complete: $RESEARCH_TOPICS" --text "$EMAIL_BODY"`. Capture exit; on failure log a single warning line (`echo "[mail] send failed (non-fatal): $ec"`) but **do not** exit non-zero — the pipeline already succeeded.

This is the only research-agent edit. No new env-var docs scattered through the file; one new env var (`RESEARCH_MAIL_TO`) added to the env-var list at SKILL.md:22-43, marked optional.

### Why this shape

- **Symlink-via-PATH (vs hardcoded plugin path):** plugin install paths differ across marketplace/local installs, but `~/.local/bin/send-local-mail` is stable. Research-agent uses `command -v` so it gracefully no-ops when local-mailer isn't installed.
- **Creds in `~/.local-mailer.env` (vs plugin dir or shell rc):** survives plugin reinstall/update and stays out of the repo. Mode 600 keeps the app password off other users on the box.
- **Nodemailer (vs `curl smtps://`):** user explicitly asked for "best JavaScript mailer." Nodemailer is the de-facto choice and gives us HTML, attachments, OAuth2 cheaply later.
- **No retries, no queue, no templating engine:** YAGNI. One script, one transport, two callers (slash command + research-agent). If templating is wanted later, add a flag.

## Verification

1. **Unit-ish — config sanity.** `node scripts/send-mail.js --to x@y.z` with no `SMTP_PASS` set must exit 1 and stderr must say which env var is missing. (No real network call.)
2. **Smoke — real send.**
   ```bash
   cp local-mailer/templates/env.example ~/.local-mailer.env   # then fill in app password
   chmod 600 ~/.local-mailer.env
   (cd local-mailer && npm install && bash scripts/install.sh)
   send-local-mail --to mlong168@gmail.com --subject "local-mailer smoke" --text "hello from claude-skills"
   ```
   Expect: `OK <messageId>` on stdout within ~3s; message arrives in inbox.
3. **Slash command.** Invoke `/mail test` in Claude Code; confirm test email arrives. Invoke `/mail config`; confirm the password is masked (e.g., `SMTP_PASS=****`).
4. **research-agent integration.** Run a small one-topic research-agent pipeline with `RESEARCH_MAIL_TO=mlong168@gmail.com` exported. Expect: existing Slack message still posts, AND a separate email arrives at the end with the same Vercel URL and GitHub URL (plain text, no `<…>` wrapping).
5. **Graceful degradation.** Temporarily rename the symlink (`mv ~/.local/bin/send-local-mail ~/.local/bin/send-local-mail.bak`) and rerun the pipeline. Expect: pipeline finishes cleanly, no email, no error — `command -v` gate skips the send.
