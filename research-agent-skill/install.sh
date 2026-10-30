#!/bin/sh
# research-agent installer — one plugin, per-harness self-contained installs.
# POSIX sh. Idempotent. --dry-run prints the copy map and writes nothing.
# Never writes ~/.agents/skills (guard below enforces it).
set -eu

SKILL_ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
INVARIANT='reviewers are never the main model drafting.'
DRY_RUN=0
ACK=0
PROJECT=''
VERSION='0.7.19'

usage() {
  cat <<'EOF'
usage: install.sh detect
       install.sh install <mimo|claude|codex|opencode|all> [--project <dir>] [--ack-reviewed] [--dry-run]
       install.sh verify <mimo|claude|codex|opencode> [--project <dir>]
       install.sh uninstall <mimo|claude|codex|opencode|all> [--project <dir>] [--dry-run]
       install.sh settings

detect              print the detected harness (first marker match wins)
install <harness>   install a self-contained copy for that harness
  --project <dir>   project root for the mimo project install (default: $PWD)
  --ack-reviewed    required gate for claude / codex / opencode installs
  --dry-run         print the copy map, write nothing
verify <harness>    assert core files present, settings parse, invariant in docs
uninstall <harness> remove what install <harness> wrote
settings            print resolved reviewers for the current host (swap rules)

Gates: claude / codex / opencode installs refuse without --ack-reviewed.
       "install all" without --ack-reviewed installs mimo and prints SKIP lines.
Never writes ~/.agents/skills.
EOF
}

die() { printf 'install.sh: %s\n' "$*" >&2; exit 1; }
log() { printf '%s\n' "$*"; }

# ---- args -----------------------------------------------------------------
[ $# -ge 1 ] || { usage; exit 1; }
CMD=$1; shift
HARNESS=''
case "$CMD" in
  detect|settings) ;;
  install|verify|uninstall)
    [ $# -ge 1 ] || die "$CMD requires <marness|all>"
    HARNESS=$1; shift
    ;;
  -h|--help|help) usage; exit 0 ;;
  *) # bare harness name is shorthand for install
    case "$CMD" in
      mimo|claude|codex|opencode|all) HARNESS=$CMD; CMD=install ;;
      *) usage; exit 1 ;;
    esac
    ;;
esac

while [ $# -gt 0 ]; do
  case "$1" in
    --project) [ $# -ge 2 ] || die "--project needs a value"; PROJECT=$2; shift 2 ;;
    --ack-reviewed) ACK=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    *) die "unknown flag: $1" ;;
  esac
done
[ -n "$PROJECT" ] || PROJECT=$PWD

# ---- safety guard ---------------------------------------------------------
guard_target() {
  case "$1" in
    "$HOME/.agents"|"$HOME/.agents/"*) die "refusing to touch ~/.agents/skills (never install there)" ;;
  esac
}

# ---- detection (first match wins) ----------------------------------------
# 1 RESEARCH_HARNESS env | 2 MIMOCODE=1/MIMOCODE_PID | 3 CLAUDECODE=1/CLAUDE_PLUGIN_ROOT
# 4 CODEX_HOME | 5 ~/.config/opencode/opencode.jsonc exists | 6 ambiguous -> stop and ask
detect_harness() {
  if [ -n "${RESEARCH_HARNESS:-}" ]; then
    case "$RESEARCH_HARNESS" in
      mimo|claude|codex|opencode)
        printf 'harness: %s\n' "$RESEARCH_HARNESS"
        printf 'evidence: RESEARCH_HARNESS=%s (override, first match)\n' "$RESEARCH_HARNESS"
        return 0 ;;
      *) die "RESEARCH_HARNESS=$RESEARCH_HARNESS is not mimo|claude|codex|opencode" ;;
    esac
  fi
  if [ "${MIMOCODE:-}" = "1" ] || [ -n "${MIMOCODE_PID:-}" ]; then
    printf 'harness: mimo\nevidence: MIMOCODE=%s MIMOCODE_PID=%s\n' "${MIMOCODE:-}" "${MIMOCODE_PID:-}"
    return 0
  fi
  if [ "${CLAUDECODE:-}" = "1" ] || [ -n "${CLAUDE_PLUGIN_ROOT:-}" ]; then
    printf 'harness: claude\nevidence: CLAUDECODE=%s CLAUDE_PLUGIN_ROOT=%s\n' "${CLAUDECODE:-}" "${CLAUDE_PLUGIN_ROOT:-}"
    return 0
  fi
  if [ -n "${CODEX_HOME:-}" ]; then
    printf 'harness: codex\nevidence: CODEX_HOME=%s\n' "$CODEX_HOME"
    return 0
  fi
  if [ -f "$HOME/.config/opencode/opencode.jsonc" ]; then
    printf 'harness: opencode\nevidence: %s exists\n' "$HOME/.config/opencode/opencode.jsonc"
    return 0
  fi
  printf 'harness: ambiguous\n'
  printf 'evidence: no marker matched (RESEARCH_HARNESS unset; MIMOCODE/MIMOCODE_PID unset; CLAUDECODE/CLAUDE_PLUGIN_ROOT unset; CODEX_HOME unset; %s absent)\n' "$HOME/.config/opencode/opencode.jsonc"
  printf 'stop: cannot determine the harness — set RESEARCH_HARNESS=mimo|claude|codex|opencode and re-run\n'
  exit 2
}

# ---- copy helpers (idempotent; --dry-run prints the map) ------------------
sync_file() {
  src=$1 dst=$2
  guard_target "$dst"
  if [ "$DRY_RUN" = 1 ]; then log "COPY $src -> $dst"; return 0; fi
  if [ -f "$dst" ] && cmp -s "$src" "$dst"; then log "unchanged: $dst"; return 0; fi
  mkdir -p "$(dirname "$dst")"
  cp "$src" "$dst"
  log "installed: $dst"
}

sync_dir() {
  src=$1 dst=$2
  guard_target "$dst"
  if [ "$DRY_RUN" = 1 ]; then log "COPY $src/ -> $dst/"; return 0; fi
  if [ -d "$dst" ] && diff -r "$src" "$dst" >/dev/null 2>&1; then log "unchanged: $dst/"; return 0; fi
  rm -rf "$dst"
  mkdir -p "$dst"
  (CDPATH='' cd -- "$src" && tar cf - .) | (CDPATH='' cd -- "$dst" && tar xf -)
  log "installed: $dst/"
}

sync_core() { # core/ + settings/ into a skill root
  root=$1
  sync_dir "$SKILL_ROOT/core" "$root/core"
  sync_dir "$SKILL_ROOT/settings" "$root/settings"
}

# ---- installers -----------------------------------------------------------
install_mimo() {
  log "-- mimo: project + user skill copies"
  for root in "$PROJECT/.mimocode/skills/research-agent" "$HOME/.mimocode/skills/research-agent"; do
    sync_file "$SKILL_ROOT/harness/mimo/SKILL.md" "$root/SKILL.md"
    sync_core "$root"
    sync_dir "$SKILL_ROOT/harness/mimo/slack" "$root/slack"
    sync_file "$SKILL_ROOT/core/workflows/research-agent.js" "$root/workflows/research-agent.js"
    # pre-unification layout kept prompt bodies at the skill root — prune so only core/ holds them
    for stale in prompts references; do
      [ -e "$root/$stale" ] || continue
      guard_target "$root/$stale"
      if [ "$DRY_RUN" = 1 ]; then log "PRUNE stale $root/$stale (now core/$stale)"; else
        rm -rf "$root/$stale"; log "pruned stale: $root/$stale"
      fi
    done
  done
}

install_opencode() {
  log "-- opencode: ~/.config/opencode/skills/research-agent"
  root="$HOME/.config/opencode/skills/research-agent"
  sync_file "$SKILL_ROOT/harness/opencode/SKILL.md" "$root/SKILL.md"
  sync_core "$root"
}

install_codex() {
  log "-- codex: ~/.codex/skills/research-agent + AGENTS.md snippet"
  root="$HOME/.codex/skills/research-agent"
  sync_file "$SKILL_ROOT/harness/codex/SKILL.md" "$root/SKILL.md"
  sync_file "$SKILL_ROOT/harness/codex/CODEX.md" "$root/CODEX.md"
  sync_dir "$SKILL_ROOT/harness/codex/agents" "$root/agents"
  sync_core "$root"
  # AGENTS.md snippet (idempotent: guarded by begin/end markers)
  agents="$HOME/.codex/AGENTS.md"
  guard_target "$agents"
  if [ "$DRY_RUN" = 1 ]; then log "APPEND harness/codex/AGENTS.md snippet -> $agents (marker-guarded)"; return 0; fi
  if [ -f "$agents" ] && grep -q 'research-agent:begin' "$agents"; then
    log "unchanged: $agents (snippet present)"
  else
    mkdir -p "$(dirname "$agents")"
    { [ -f "$agents" ] && cat "$agents"; printf '\n'; cat "$SKILL_ROOT/harness/codex/AGENTS.md"; } >> "$agents.tmp"
    mv "$agents.tmp" "$agents"
    log "installed: snippet appended to $agents"
  fi
}

install_claude() {
  log "-- claude: plugin cache + installed_plugins.json v2 + marketplace config"
  [ -f "$SKILL_ROOT/harness/claude/.claude-plugin/plugin.json" ] || die "missing plugin.json"
  ver=$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$SKILL_ROOT/harness/claude/.claude-plugin/plugin.json" | head -1)
  [ -n "$ver" ] || ver=$VERSION
  root="$HOME/.claude/plugins/cache/local-skills/research-agent/$ver"
  sync_dir "$SKILL_ROOT/harness/claude/.claude-plugin" "$root/.claude-plugin"
  sync_dir "$SKILL_ROOT/harness/claude/commands" "$root/commands"
  sync_dir "$SKILL_ROOT/harness/claude/agents" "$root/agents"
  sync_dir "$SKILL_ROOT/harness/claude/skills" "$root/skills"
  sync_file "$SKILL_ROOT/harness/claude/skills/research-agent/SKILL.md" "$root/SKILL.md"
  sync_core "$root"
  if [ "$DRY_RUN" = 1 ]; then
    log "WRITE $HOME/.claude/plugins/installed_plugins.json entry research-agent@local-skills"
    log "WRITE $HOME/.claude/plugins/known_marketplaces.json entry local-skills (if absent)"
    return 0
  fi
  REPO_ROOT=$(CDPATH='' cd -- "$SKILL_ROOT/.." 2>/dev/null && pwd || printf '%s' "$SKILL_ROOT")
  sha=$(git -C "$SKILL_ROOT" rev-parse HEAD 2>/dev/null || printf 'unknown')
  claude_plugin_json="$HOME/.claude/plugins/installed_plugins.json"
  claude_mkts_json="$HOME/.claude/plugins/known_marketplaces.json"
  guard_target "$claude_plugin_json"; guard_target "$claude_mkts_json"
  python3 - "$claude_plugin_json" "$claude_mkts_json" "$root" "$ver" "$sha" "$REPO_ROOT" <<'PY'
import json, os, sys, datetime
plugins_path, mkts_path, install_path, ver, sha, repo = sys.argv[1:7]
now = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.000Z")

def load(p, default):
    try:
        with open(p) as f:
            return json.load(f)
    except FileNotFoundError:
        return default

# installed_plugins.json v2 entry shape (mirrors the research-agent@local-skills entry)
data = load(plugins_path, {"version": 2, "plugins": {}})
data.setdefault("version", 2)
data.setdefault("plugins", {})
key = "research-agent@local-skills"
old = (data["plugins"].get(key) or [{}])[0]
data["plugins"][key] = [{
    "scope": "user",
    "installPath": install_path,
    "version": ver,
    "installedAt": old.get("installedAt", now),
    "lastUpdated": now,
    "gitCommitSha": sha,
}]
with open(plugins_path, "w") as f:
    json.dump(data, f, indent=2)

# marketplace config: local-skills directory marketplace (add only if absent)
mkts = load(mkts_path, {})
if "local-skills" not in mkts:
    mkts["local-skills"] = {
        "source": {"source": "directory", "path": repo},
        "installLocation": repo,
        "lastUpdated": now,
        "autoUpdate": True,
    }
    with open(mkts_path, "w") as f:
        json.dump(mkts, f, indent=2)
print("installed: installed_plugins.json entry %s (version %s)" % (key, ver))
PY
}

require_ack() {
  case "$1" in
    claude|codex|opencode)
      [ "$ACK" = 1 ] || die "$1 install is gated: re-run with --ack-reviewed (reviewers are external and independent; see settings/NOTES.md)"
      ;;
  esac
}

# ---- verify ---------------------------------------------------------------
INV_FILES='README.md core/references/harness-matrix.md settings/NOTES.md'
CORE_FILES='SKILL.md core/SKILL.body.md core/workflows/research-agent.js settings/research-agent.settings.json settings/NOTES.md
core/prompts/research-worker.md core/prompts/haskell-verifier.md core/prompts/lean-verifier.md
core/prompts/synthesis-agent.md core/prompts/pipeline-validator.md core/prompts/knowledge-base-builder.md
core/prompts/og-image-generator.md core/prompts/social-posts.md core/prompts/website-builder.md
core/references/haskell-patterns.md core/references/paper-format.md core/references/pipeline-stages.md
core/references/platform-constraints.md core/references/style-standard.md core/references/team-protocol.md
core/references/website-template.md core/references/writing-standard.md core/references/harness-matrix.md'

verify_tree() {
  root=$1 label=$2
  fail=0
  for f in $CORE_FILES; do
    [ -f "$root/$f" ] || { log "MISSING: $root/$f"; fail=1; }
  done
  if command -v python3 >/dev/null 2>&1; then
    python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$root/settings/research-agent.settings.json" \
      || { log "SETTINGS PARSE FAIL: $root/settings/research-agent.settings.json"; fail=1; }
  fi
  [ "$fail" = 0 ] && log "verify $label: core files + settings OK ($root)"
  return "$fail"
}

verify_harness() {
  case "$1" in
    mimo)
      verify_tree "$PROJECT/.mimocode/skills/research-agent" "mimo(project)" || return 1
      verify_tree "$HOME/.mimocode/skills/research-agent" "mimo(user)" || return 1
      ;;
    opencode)
      verify_tree "$HOME/.config/opencode/skills/research-agent" "opencode" || return 1 ;;
    codex)
      verify_tree "$HOME/.codex/skills/research-agent" "codex" || return 1
      [ -f "$HOME/.codex/skills/research-agent/CODEX.md" ] || { log "MISSING: CODEX.md overlay"; return 1; }
      grep -q 'research-agent:begin' "$HOME/.codex/AGENTS.md" 2>/dev/null || { log "MISSING: AGENTS.md snippet"; return 1; }
      ;;
    claude)
      cver=$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$SKILL_ROOT/harness/claude/.claude-plugin/plugin.json" | head -1)
      verify_tree "$HOME/.claude/plugins/cache/local-skills/research-agent/$cver" "claude" || return 1
      python3 - "$HOME/.claude/plugins/installed_plugins.json" <<'PY' || return 1
import json, sys
d = json.load(open(sys.argv[1]))
key = "research-agent@local-skills"
assert d.get("version") == 2, "installed_plugins.json version != 2"
e = d["plugins"][key][0]
for k in ("scope", "installPath", "version"):
    assert e.get(k), "entry missing " + k
print("verify claude: installed_plugins.json v2 entry OK (" + key + ")")
PY
      ;;
    *) die "unknown harness: $1" ;;
  esac
  return 0
}

cmd_verify() {
  fail=0
  for f in $INV_FILES; do
    grep -qF "$INVARIANT" "$SKILL_ROOT/$f" 2>/dev/null || { log "INVARIANT MISSING in $f: $INVARIANT"; fail=1; }
  done
  [ "$fail" = 0 ] && log "verify docs: invariant sentence present in README.md + core/references/harness-matrix.md + settings/NOTES.md"
  case "$HARNESS" in
    all) for h in mimo opencode codex claude; do verify_harness "$h" || fail=1; done ;;
    *) verify_harness "$HARNESS" || fail=1 ;;
  esac
  [ "$fail" = 0 ] || die "verify FAILED"
  log "verify: PASS"
}

# ---- uninstall ------------------------------------------------------------
uninstall_tree() {
  root=$1
  guard_target "$root"
  if [ "$DRY_RUN" = 1 ]; then log "REMOVE $root"; return 0; fi
  [ -e "$root" ] && { rm -rf "$root"; log "removed: $root"; } || log "absent: $root"
}

cmd_uninstall() {
  case "$HARNESS" in
    mimo)
      uninstall_tree "$PROJECT/.mimocode/skills/research-agent"
      uninstall_tree "$HOME/.mimocode/skills/research-agent"
      ;;
    opencode) uninstall_tree "$HOME/.config/opencode/skills/research-agent" ;;
    codex)
      uninstall_tree "$HOME/.codex/skills/research-agent"
      if [ "$DRY_RUN" = 1 ]; then log "REMOVE AGENTS.md snippet from $HOME/.codex/AGENTS.md"; else
        if [ -f "$HOME/.codex/AGENTS.md" ]; then
          python3 - "$HOME/.codex/AGENTS.md" <<'PY'
import re, sys
p = sys.argv[1]
s = open(p).read()
s2 = re.sub(r"<!-- research-agent:begin.*?research-agent:end -->\n?", "", s, flags=re.S)
if s2 != s:
    open(p, "w").write(s2)
    print("removed: research-agent snippet from " + p)
else:
    print("absent: research-agent snippet in " + p)
PY
        fi
      fi
      ;;
    claude)
      ver=$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$SKILL_ROOT/harness/claude/.claude-plugin/plugin.json" | head -1)
      uninstall_tree "$HOME/.claude/plugins/cache/local-skills/research-agent/$ver"
      if [ "$DRY_RUN" = 1 ]; then log "REMOVE installed_plugins.json entry research-agent@local-skills"; else
        python3 - "$HOME/.claude/plugins/installed_plugins.json" <<'PY'
import json, sys
p = sys.argv[1]
d = json.load(open(p))
d.get("plugins", {}).pop("research-agent@local-skills", None)
json.dump(d, open(p, "w"), indent=2)
print("removed: research-agent@local-skills entry")
PY
      fi
      ;;
    all) for h in mimo opencode codex claude; do HARNESS=$h; cmd_uninstall; done ;;
    *) die "unknown harness: $HARNESS" ;;
  esac
}

# ---- settings (swap-rule resolution) -------------------------------------
cmd_settings() {
  model=${RESEARCH_DRAFTER_MODEL:-}
  family=unknown
  if [ -n "$model" ]; then :; elif [ -f "$HOME/.codex/config.toml" ] && grep -q '^model' "$HOME/.codex/config.toml" 2>/dev/null; then
    model=$(sed -n 's/^model[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' "$HOME/.codex/config.toml" | head -1)
  elif [ -f "$HOME/.config/opencode/opencode.jsonc" ]; then
    model=$(sed -n 's/.*"model"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$HOME/.config/opencode/opencode.jsonc" | head -1)
  fi
  m=$(printf '%s' "$model" | tr '[:upper:]' '[:lower:]')
  case "$m" in
    *gemini*|*google*) family=gemini ;;
    *gpt*|*openai*|*codex*|o1*|o3*|o4*) family=openai ;;
    *claude*|*anthropic*) family=claude ;;
    *glm*) family=glm ;;
    *mimo*|*xiaomi*) family=mimo ;;
  esac
  sci_model=$(grep -m1 '"model"' "$SKILL_ROOT/settings/research-agent.settings.json" | sed 's/.*"model"[[:space:]]*:[[:space:]]*"//;s/".*//')
  fb_model=$(grep -m1 '"fallback"' "$SKILL_ROOT/settings/research-agent.settings.json" | sed 's/.*"fallback"[[:space:]]*:[[:space:]]*"//;s/".*//')
  code_model=$(grep -m2 '"model"' "$SKILL_ROOT/settings/research-agent.settings.json" | tail -1 | sed 's/.*"model"[[:space:]]*:[[:space:]]*"//;s/".*//')
  science="agy / $sci_model (fallback $fb_model)"
  code="codex / $code_model"
  note='defaults (host-disjoint vendors)'
  case "$family" in
    gemini) science='claude (swapped: host gemini family)'; note='science lane swapped to Claude — AGY shares the drafter family' ;;
    openai) code='claude (swapped: host openai/codex family)'; note='code lane swapped to Claude — Codex never reviews itself' ;;
  esac
  log "settings: $SKILL_ROOT/settings/research-agent.settings.json"
  log "drafter: ${model:-<none>}"
  log "host family: $family"
  log "science review: $science"
  log "code/format review: $code"
  log "note: $note"
  log "noSelfReview: true — $INVARIANT"
}

# ---- dispatch -------------------------------------------------------------
case "$CMD" in
  detect) detect_harness ;;
  settings) cmd_settings ;;
  install)
    case "$HARNESS" in
      all)
        install_mimo
        for h in opencode claude codex; do
          if [ "$ACK" = 1 ]; then require_ack "$h"; "install_$h"; else
            log "SKIP $h: gated behind --ack-reviewed (not installed)"
          fi
        done
        ;;
      mimo|claude|codex|opencode)
        require_ack "$HARNESS"
        "install_$HARNESS"
        ;;
      *) die "unknown harness: $HARNESS" ;;
    esac
    log "install: done (dry-run=$DRY_RUN)"
    ;;
  verify) cmd_verify ;;
  uninstall) cmd_uninstall ;;
  *) usage; exit 1 ;;
esac
