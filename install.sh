#!/usr/bin/env bash
#
# ██╗     ███████╗ ██████╗  ██████╗     ██╗     ███████╗ █████╗  ██████╗ ██╗   ██╗███████╗
# ██║     ██╔════╝██╔════╝ ██╔═══██╗    ██║     ██╔════╝██╔══██╗██╔════╝ ██║   ██║██╔════╝
# ██║     █████╗  ██║  ███╗██║   ██║    ██║     █████╗  ███████║██║  ███╗██║   ██║█████╗
# ██║     ██╔══╝  ██║   ██║██║   ██║    ██║     ██╔══╝  ██╔══██║██║   ██║██║   ██║██╔══╝
# ███████╗███████╗╚██████╔╝╚██████╔╝    ███████╗███████╗██║  ██║╚██████╔╝╚██████╔╝███████╗
# ╚══════╝╚══════╝ ╚═════╝  ╚═════╝     ╚══════╝╚══════╝╚═╝  ╚═╝ ╚═════╝  ╚═════╝ ╚══════╝
#
# install.sh — the turnkey installer for the FIRST(R) LEGO(R) League Team Kit.
#
# Run it, answer a couple of plain questions, and it writes your team config and puts your
# signup site online. No Node, no Python, no build step — just bash + coreutils + curl (and
# Docker only if you pick the self-host path).
#
#   Direct:   ./install.sh
#   Piped:    curl -fsSL https://raw.githubusercontent.com/delorenj/first-lego-league-team-kit/main/install.sh | bash
#   Help:     ./install.sh --help
#
# Design notes for maintainers:
#   * POSIX-friendly bash, kept compatible with macOS's stock bash 3.2 — NO associative arrays,
#     no `${var,,}`, no `mapfile`. Lowercasing goes through `tr`.
#   * Deploy paths are a dispatch table (see run_path). Adding a path = write one deploy_<name>()
#     function and add one line to the `case` in run_path(). That's the whole extension seam.
#   * Guardrails (AGENTS.md §8): never bake a real town / email / URL / personal infra as a default.
#     Every default here is a neutral placeholder. The installer only ever collects the COACH's own
#     details — never a child's data.
#
# License: Apache-2.0. Part of https://github.com/delorenj/first-lego-league-team-kit
# ─────────────────────────────────────────────────────────────────────────────────────────────

set -euo pipefail

# ════════════════════════════════════════════════════════════════════════════════════════════
#  Constants
# ════════════════════════════════════════════════════════════════════════════════════════════

REPO_URL="https://github.com/delorenj/first-lego-league-team-kit.git"
CLONE_DIR_DEFAULT="first-lego-league-team-kit"

# ════════════════════════════════════════════════════════════════════════════════════════════
#  Runtime state (populated by parse_args + collect_team). All have neutral, shippable defaults.
# ════════════════════════════════════════════════════════════════════════════════════════════

NONINTERACTIVE=0        # 1 = never prompt; use flags/env/defaults (for CI + power users)
DRY_RUN=0               # 1 = prepare + validate everything, but do NOT run the live action
PATH_CHOICE=""          # email | compose | digitalocean | traefik (empty = show the menu)
REPO_ROOT=""            # resolved kit checkout root
TTY=""                  # where interactive reads come from (stdin or /dev/tty)

# Where the generated team config is written. Overridable so tests never clobber a live config.js.
CONFIG_OUT=""           # default resolved to $REPO_ROOT/apps/web/config.js once root is known
COMPOSE_ENV_OUT=""      # default resolved to $REPO_ROOT/deploy/compose/.env

# Team fields (config.js). Defaults are deliberately neutral placeholders — never Clinton/personal.
TEAM_TOWN="${TEAM_TOWN:-Your Town}"
TEAM_REGION="${TEAM_REGION:-Your Town, ST}"
TEAM_SEASON_LABEL="${TEAM_SEASON_LABEL:-Fall 2026}"
TEAM_SEASON_NAME="${TEAM_SEASON_NAME:-2026–27 BIOGLOW}"
TEAM_COACH_NAME="${TEAM_COACH_NAME:-Coach}"
TEAM_COACH_EMAIL="${TEAM_COACH_EMAIL:-coach@example.com}"
TEAM_SPOTS="${TEAM_SPOTS:-8}"
TEAM_COST="${TEAM_COST:-\$125}"
TEAM_SCHOOL="${TEAM_SCHOOL:-your school}"

# Adapter contract fields (AGENTS.md §3).
SIGNUP_ENDPOINT="${SIGNUP_ENDPOINT:-}"
OPTIMISTIC_SUBMIT="${OPTIMISTIC_SUBMIT:-false}"
OPTIMISTIC_EXPLICIT=0   # 1 once the user passes --optimistic; then we never auto-override it
SITE_URL="${SITE_URL:-}"

# Email/form-service path: which catcher. Empty = ask (interactive) or infer (non-interactive).
FORM_SERVICE="${FORM_SERVICE:-}"   # formspree | google

# Optional per-team brick colors (omitted unless all four are supplied).
TEAM_COLOR_RED="${TEAM_COLOR_RED:-}"
TEAM_COLOR_YELLOW="${TEAM_COLOR_YELLOW:-}"
TEAM_COLOR_BLUE="${TEAM_COLOR_BLUE:-}"
TEAM_COLOR_GREEN="${TEAM_COLOR_GREEN:-}"

# Compose path
SITE_DOMAIN="${SITE_DOMAIN:-localhost}"

# DigitalOcean path — one-click Droplet via doctl + cloud-init (reuses the Compose/Caddy stack).
DO_REGION="${DO_REGION:-nyc1}"
DO_SIZE="${DO_SIZE:-s-1vcpu-1gb}"
DO_IMAGE="${DO_IMAGE:-ubuntu-24-04-x64}"
DO_DROPLET_NAME="${DO_DROPLET_NAME:-lego-league}"
DO_PROVISION="${DO_PROVISION:-0}"   # 1 = allow the real (billable) droplet create in non-interactive mode
DO_TARGET="${DO_TARGET:-}"          # ""=ask, droplet | app  (Droplet vs App Platform static site)
DO_APP_REPO="${DO_APP_REPO:-}"      # owner/name of the GitHub repo App Platform builds from
DO_APP_BRANCH="${DO_APP_BRANCH:-main}"

# Own-your-data backend (services/api) — offered on the box paths (Compose + DO Droplet).
USE_BACKEND="${USE_BACKEND:-}"      # ""=ask, 1=run the built-in backend, 0=static + form-service
ROSTER_USER="${ROSTER_USER:-}"      # roster login (defaults to "coach")
ROSTER_PASS="${ROSTER_PASS:-}"      # roster password (a strong one is generated if unset)
RESOLVED_BACKEND=0                  # set by prepare_signup_destination()

# ════════════════════════════════════════════════════════════════════════════════════════════
#  Output helpers — colorful, but only when writing to a real terminal.
# ════════════════════════════════════════════════════════════════════════════════════════════

if [ -t 1 ]; then
  C_RED=$'\033[38;2;208;16;18m'      # brick red   #D01012
  C_YEL=$'\033[38;2;246;190;0m'      # brick yellow #F6BE00
  C_BLU=$'\033[38;2;0;87;166m'       # brick blue  #0057A6
  C_GRN=$'\033[38;2;0;135;62m'       # brick green #00873E
  C_INK=$'\033[1m'
  C_DIM=$'\033[2m'
  C_RST=$'\033[0m'
else
  C_RED=""; C_YEL=""; C_BLU=""; C_GRN=""; C_INK=""; C_DIM=""; C_RST=""
fi

say()  { printf '%s\n' "$*"; }
info() { printf '%s\n' "$*"; }
ok()   { printf '%s✓%s %s\n' "$C_GRN" "$C_RST" "$*"; }
warn() { printf '%s!%s %s\n' "$C_YEL" "$C_RST" "$*" >&2; }
err()  { printf '%s✗%s %s\n' "$C_RED" "$C_RST" "$*" >&2; }
dim()  { printf '%s%s%s\n' "$C_DIM" "$*" "$C_RST"; }

# A chunky, on-brand section banner (the "stud strip" in text form).
banner() {
  local title="$1" color="${2:-$C_YEL}"
  printf '\n%s%s%s\n' "$color" "🟥🟨🟦🟩 ────────────────────────────────────────────────" "$C_RST"
  printf '%s%s %s%s\n'  "$color$C_INK" "🧱" "$title" "$C_RST"
  printf '%s%s%s\n\n' "$color" "──────────────────────────────────────────────────────" "$C_RST"
}

die() { err "$*"; exit 1; }

# ════════════════════════════════════════════════════════════════════════════════════════════
#  Interactive input (works even when the script itself was piped into `bash`).
# ════════════════════════════════════════════════════════════════════════════════════════════

# Decide once where prompts read from. If stdin is a terminal, use it; else fall back to /dev/tty
# (the case when the script arrived via `curl … | bash`). If neither is available, we can't prompt,
# so force non-interactive mode.
init_tty() {
  if [ -t 0 ]; then
    TTY="/dev/stdin"
  elif [ -r /dev/tty ]; then
    TTY="/dev/tty"
  else
    TTY=""
    if [ "$NONINTERACTIVE" != "1" ]; then
      warn "No terminal available for prompts — running non-interactively with defaults."
      NONINTERACTIVE=1
    fi
  fi
}

# ask VAR "Prompt text" "default"   →   sets VAR to the answer (or the default on empty/EOF).
ask() {
  local __var="$1" __prompt="$2" __default="${3:-}" __ans=""
  if [ "$NONINTERACTIVE" = "1" ] || [ -z "$TTY" ]; then
    printf -v "$__var" '%s' "$__default"
    return 0
  fi
  if [ -n "$__default" ]; then
    printf '%s%s%s %s(%s)%s ' "$C_INK" "$__prompt" "$C_RST" "$C_DIM" "$__default" "$C_RST"
  else
    printf '%s%s%s ' "$C_INK" "$__prompt" "$C_RST"
  fi
  IFS= read -r __ans < "$TTY" || __ans=""
  [ -z "$__ans" ] && __ans="$__default"
  printf -v "$__var" '%s' "$__ans"
}

# confirm "Question" [y|n]   →   returns 0 for yes, 1 for no. Default answer used on EOF/non-interactive.
confirm() {
  local __q="$1" __def="${2:-y}" __ans="" __hint="[Y/n]"
  [ "$__def" = "n" ] && __hint="[y/N]"
  if [ "$NONINTERACTIVE" = "1" ] || [ -z "$TTY" ]; then
    if [ "$__def" = "y" ]; then return 0; else return 1; fi
  fi
  printf '%s%s%s %s ' "$C_INK" "$__q" "$C_RST" "$__hint"
  IFS= read -r __ans < "$TTY" || __ans=""
  [ -z "$__ans" ] && __ans="$__def"
  case "$__ans" in
    [Yy]|[Yy][Ee][Ss]) return 0 ;;
    *) return 1 ;;
  esac
}

lc() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

# ════════════════════════════════════════════════════════════════════════════════════════════
#  Repo-root resolution + (if piped) offer to clone.
# ════════════════════════════════════════════════════════════════════════════════════════════

# Portable "does this dir look like the kit?" test.
is_kit_root() { [ -f "$1/apps/web/index.html" ] && [ -f "$1/apps/web/config.example.js" ]; }

# Walk up from a starting dir looking for the kit root. Echoes the root or nothing.
find_up() {
  local d="$1"
  while [ -n "$d" ] && [ "$d" != "/" ]; do
    if is_kit_root "$d"; then printf '%s' "$d"; return 0; fi
    d="$(dirname "$d")"
  done
  is_kit_root "/" && { printf '%s' "/"; return 0; }
  return 1
}

# Resolve the directory containing this script (best effort; empty when piped via stdin).
script_dir() {
  local src="${BASH_SOURCE[0]:-}"
  case "$src" in
    ""|bash|sh|-bash|-sh|/dev/fd/*|/proc/self/fd/*) return 1 ;;
  esac
  [ -f "$src" ] || return 1
  ( cd "$(dirname "$src")" >/dev/null 2>&1 && pwd )
}

ensure_repo_root() {
  local d=""
  # 1) Next to the script (the normal `./install.sh` from a clone).
  if d="$(script_dir 2>/dev/null)"; then
    if REPO_ROOT="$(find_up "$d" 2>/dev/null)"; then return 0; fi
  fi
  # 2) The current directory (e.g. `bash install.sh` from the repo root).
  if REPO_ROOT="$(find_up "$PWD" 2>/dev/null)"; then return 0; fi

  # 3) We're piped and not inside a checkout → offer to clone.
  banner "Let's get you a copy of the kit" "$C_BLU"
  say "It looks like you're running this straight from the internet (nice!), so there's no"
  say "kit folder here yet. I can grab a fresh copy for you with git."
  say ""
  if ! command -v git >/dev/null 2>&1; then
    err "git isn't installed, so I can't clone automatically."
    say "Install git, or download the kit manually:"
    say "    ${C_BLU}${REPO_URL%.git}${C_RST}"
    die "No repo to work in."
  fi
  local dir="$CLONE_DIR_DEFAULT"
  ask dir "Clone into which folder?" "$CLONE_DIR_DEFAULT"
  if [ -e "$dir" ] && is_kit_root "$dir"; then
    ok "Found an existing kit in ./$dir — using it."
  elif [ -e "$dir" ]; then
    die "./$dir already exists and isn't a kit checkout. Move it aside and re-run."
  else
    say "Cloning ${REPO_URL} → ./$dir …"
    git clone --depth 1 "$REPO_URL" "$dir" || die "Clone failed."
    ok "Cloned."
  fi
  REPO_ROOT="$(cd "$dir" && pwd)"
  say ""
  say "Handing off to the copy I just cloned…"
  exec bash "$REPO_ROOT/install.sh" "$@"
}

# ════════════════════════════════════════════════════════════════════════════════════════════
#  Config writing — turn the collected fields into apps/web/config.js.
# ════════════════════════════════════════════════════════════════════════════════════════════

# JS-escape a string for embedding inside a double-quoted JS literal.
js_escape() {
  local s="$1"
  s="${s//\\/\\\\}"   # backslashes first
  s="${s//\"/\\\"}"   # then double quotes
  s="${s//$'\n'/ }"   # collapse any stray newlines
  s="${s//$'\t'/ }"
  printf '%s' "$s"
}

# Coerce spots to a bare integer (config uses it unquoted); fall back to 8 if it isn't a number.
sanitize_spots() {
  case "$1" in
    ''|*[!0-9]*) printf '8' ;;
    *) printf '%s' "$1" ;;
  esac
}

# Normalize a truthy/falsey string to the JS literal true/false.
norm_bool() {
  case "$(lc "$1")" in
    1|true|yes|y|on) printf 'true' ;;
    *) printf 'false' ;;
  esac
}

write_config() {
  local out="$CONFIG_OUT"
  local dir; dir="$(dirname "$out")"
  [ -d "$dir" ] || die "Target directory does not exist: $dir"

  # Back up an existing config so a re-run never silently destroys a coach's work.
  # The PID suffix keeps two runs in the same second from colliding.
  if [ -f "$out" ]; then
    local bak="$out.bak.$(date +%Y%m%d%H%M%S).$$"
    cp "$out" "$bak"
    warn "Existing config saved to: $bak"
  fi

  local spots; spots="$(sanitize_spots "$TEAM_SPOTS")"
  local optimistic; optimistic="$(norm_bool "$OPTIMISTIC_SUBMIT")"

  # Optional colors block — only when all four are provided.
  local colors_block=""
  if [ -n "$TEAM_COLOR_RED" ] && [ -n "$TEAM_COLOR_YELLOW" ] && \
     [ -n "$TEAM_COLOR_BLUE" ] && [ -n "$TEAM_COLOR_GREEN" ]; then
    colors_block="$(printf '\n  colors: { red: "%s", yellow: "%s", blue: "%s", green: "%s" },\n' \
      "$(js_escape "$TEAM_COLOR_RED")" "$(js_escape "$TEAM_COLOR_YELLOW")" \
      "$(js_escape "$TEAM_COLOR_BLUE")" "$(js_escape "$TEAM_COLOR_GREEN")")"
  fi

  cat > "$out" <<EOF
// ── $(js_escape "$TEAM_TOWN") — team configuration ──────────────────────────────────────────
// Generated by install.sh on $(date -u +%Y-%m-%dT%H:%M:%SZ). Safe to edit by hand or re-run the installer.
// This file is git-ignored (per-deployment config). It holds only PUBLIC info (your coach email
// shows on the page) — never secrets or API keys. Guide: docs/INSTALL.md (or re-run ./install.sh).
window.TEAM_CONFIG = {
  // Where signups go — set by your deploy path. Empty ("") = "email the coach" fallback only.
  signupEndpoint: "$(js_escape "$SIGNUP_ENDPOINT")",

  // true ONLY for endpoints that can't return CORS headers (e.g. a Google Apps Script Web App).
  optimisticSubmit: $optimistic,

  // Optional public site URL, used only for the og:url social-share tag. "" to omit.
  siteUrl: "$(js_escape "$SITE_URL")",

  // ── Your team ──────────────────────────────────────────────────────────────
  townOrTeam:   "$(js_escape "$TEAM_TOWN")",
  region:       "$(js_escape "$TEAM_REGION")",
  seasonLabel:  "$(js_escape "$TEAM_SEASON_LABEL")",
  seasonName:   "$(js_escape "$TEAM_SEASON_NAME")",
  coachName:    "$(js_escape "$TEAM_COACH_NAME")",
  coachEmail:   "$(js_escape "$TEAM_COACH_EMAIL")",
  spots:        $spots,
  costPerChild: "$(js_escape "$TEAM_COST")",
  schoolName:   "$(js_escape "$TEAM_SCHOOL")",$colors_block
};
EOF
  ok "Wrote team config → $out"

  # Friendly, dependency-free syntax check when Node happens to be installed (skipped otherwise).
  if command -v node >/dev/null 2>&1; then
    if node --check "$out" >/dev/null 2>&1; then
      ok "Config is valid JavaScript."
    else
      err "The generated config has a syntax error — please review $out"
    fi
  fi
}

# ════════════════════════════════════════════════════════════════════════════════════════════
#  Team-info collection
# ════════════════════════════════════════════════════════════════════════════════════════════

collect_team() {
  banner "Tell me about your team" "$C_RED"
  say "A few plain questions. Press ${C_INK}Enter${C_RST} to accept the default in (parentheses)."
  say "Everything here is about ${C_INK}you, the coach${C_RST} — we never collect a child's info. 🧱"
  say ""

  ask TEAM_TOWN         "Your town or team name"                  "$TEAM_TOWN"
  # Default the region off the town so the small line under the studs isn't a placeholder.
  if [ "$TEAM_REGION" = "Your Town, ST" ]; then TEAM_REGION="$TEAM_TOWN, ST"; fi
  ask TEAM_REGION       "Region (small line under the logo)"      "$TEAM_REGION"
  ask TEAM_SCHOOL       "Full school name"                        "$TEAM_SCHOOL"
  ask TEAM_COACH_NAME   "Your first name (the coach)"             "$TEAM_COACH_NAME"
  ask TEAM_COACH_EMAIL  "Your email (shown publicly for questions + fallback)" "$TEAM_COACH_EMAIL"
  ask TEAM_SPOTS        "How many roster spots?"                  "$TEAM_SPOTS"
  ask TEAM_COST         "Cost per child (as text, e.g. \$125 or Free)" "$TEAM_COST"
  ask TEAM_SEASON_LABEL "Short season tag (kicker)"               "$TEAM_SEASON_LABEL"
  ask TEAM_SEASON_NAME  "Official season name (footer)"           "$TEAM_SEASON_NAME"

  # Gentle validation — warn but never block (a coach may have an unusual address).
  case "$TEAM_COACH_EMAIL" in
    *@*.*) : ;;
    *) warn "That coach email looks off ('$TEAM_COACH_EMAIL') — double-check it before you print flyers." ;;
  esac

  say ""
  ok "Great, ${TEAM_COACH_NAME}! Here's ${TEAM_TOWN}'s setup so far:"
  dim "   town=$TEAM_TOWN | school=$TEAM_SCHOOL | spots=$(sanitize_spots "$TEAM_SPOTS") | cost=$TEAM_COST | email=$TEAM_COACH_EMAIL"
}

# ════════════════════════════════════════════════════════════════════════════════════════════
#  Hosting menu → dispatch table
# ════════════════════════════════════════════════════════════════════════════════════════════

# The extension seam: add a deploy_<name>() function, then one line here. Nothing else to touch.
run_path() {
  case "$1" in
    email)         deploy_email ;;
    compose)       deploy_compose ;;
    digitalocean)  deploy_digitalocean ;;
    traefik)       deploy_traefik ;;
    *) die "Unknown hosting path: '$1' (expected: email|compose|digitalocean|traefik)" ;;
  esac
}

hosting_menu() {
  banner "How do you want to host it?" "$C_BLU"
  say "  ${C_GRN}1)${C_RST} ${C_INK}Email me the signups${C_RST}  ${C_DIM}(recommended — no server, free, signups land in your inbox)${C_RST}"
  say "  ${C_BLU}2)${C_RST} ${C_INK}Self-host with Docker${C_RST} ${C_DIM}(own your data on your own box; needs Docker + a domain)${C_RST}"
  say "  ${C_YEL}3)${C_RST} ${C_INK}DigitalOcean${C_RST}         ${C_DIM}(cloud droplet / App Platform — guided manual runbook)${C_RST}"
  say "  ${C_RED}4)${C_RST} ${C_INK}Your own reverse proxy${C_RST} ${C_DIM}(Traefik + tunnel, parameterized — guided manual runbook)${C_RST}"
  say ""
  local choice=""
  ask choice "Pick a number" "1"
  case "$choice" in
    1) printf 'email' ;;
    2) printf 'compose' ;;
    3) printf 'digitalocean' ;;
    4) printf 'traefik' ;;
    email|compose|digitalocean|traefik) printf '%s' "$choice" ;;
    *) warn "Didn't recognize '$choice' — defaulting to the easy path (email)." >&2; printf 'email' ;;
  esac
}

# ════════════════════════════════════════════════════════════════════════════════════════════
#  PATH A — Email / form service  (RECOMMENDED, zero server)  [v1, fully implemented]
# ════════════════════════════════════════════════════════════════════════════════════════════

deploy_email() {
  banner "Path: Email me the signups (no server)" "$C_GRN"
  say "Your signup page is just static files. We point it at a free service that catches each"
  say "submission and emails it to you (or drops it in your own Google Sheet). Nothing to run."
  say ""

  # ── Which catcher? Precedence: --form-service flag > interactive pick > infer from endpoint ──
  local svc="$(lc "$FORM_SERVICE")"
  if [ -z "$svc" ]; then
    if [ "$NONINTERACTIVE" = "1" ] || [ -z "$TTY" ]; then
      case "$SIGNUP_ENDPOINT" in
        *script.google.com*) svc="google" ;;
        *) svc="formspree" ;;
      esac
    else
      say "Pick your catcher:"
      say "  ${C_GRN}1)${C_RST} ${C_INK}Formspree${C_RST}     ${C_DIM}(easiest — signups arrive in your email; free tier is plenty)${C_RST}"
      say "  ${C_BLU}2)${C_RST} ${C_INK}Google Apps Script${C_RST} ${C_DIM}(own the data — signups append to your own Google Sheet)${C_RST}"
      say ""
      local pick=""; ask pick "Which one" "1"
      case "$(lc "$pick")" in 2|google|apps|"apps script"|sheet) svc="google" ;; *) svc="formspree" ;; esac
    fi
  fi

  case "$svc" in
    google|apps|sheet)
      svc="google"
      if [ "$NONINTERACTIVE" != "1" ] && [ -n "$TTY" ]; then
        say ""
        say "${C_INK}Google Apps Script — signups → your own Google Sheet${C_RST}"
        say "  1. Create a Google Sheet, then Extensions → Apps Script, and paste this:"
        say ""
        say "${C_DIM}     function doPost(e) {"
        say "       var sh = SpreadsheetApp.getActiveSpreadsheet().getSheetByName('Signups')"
        say "                || SpreadsheetApp.getActiveSpreadsheet().insertSheet('Signups');"
        say "       if (sh.getLastRow() === 0)"
        say "         sh.appendRow(['when','parent','email','phone','child','grade','notes','source']);"
        say "       var p = e.parameter;"
        say "       sh.appendRow([new Date(), p.parentName, p.parentEmail, p.parentPhone,"
        say "                     p.childName, p.childGrade, p.notes, p.source]);"
        say "       return ContentService.createTextOutput(JSON.stringify({ok:true}))"
        say "                            .setMimeType(ContentService.MimeType.JSON);"
        say "     }${C_RST}"
        say ""
        say "  2. Deploy → New deployment → type ${C_INK}Web app${C_RST} → execute as ${C_INK}you${C_RST}, access ${C_INK}Anyone${C_RST}."
        say "  3. Copy the ${C_INK}/exec${C_RST} URL it gives you (and add Sheet → Tools → Notifications for email alerts)."
        say ""
        ask SIGNUP_ENDPOINT "Paste your Apps Script /exec URL (or leave blank to add later)" "$SIGNUP_ENDPOINT"
      fi
      # Apps Script can't return CORS headers → the page must assume success after POSTing.
      # Honor an explicit --optimistic; otherwise the correct value for Apps Script is true.
      if [ "$OPTIMISTIC_EXPLICIT" != "1" ]; then OPTIMISTIC_SUBMIT="true"; fi
      ok "Using Google Apps Script (optimisticSubmit=$(norm_bool "$OPTIMISTIC_SUBMIT"))."
      ;;
    *)
      svc="formspree"
      if [ "$NONINTERACTIVE" != "1" ] && [ -n "$TTY" ]; then
        say ""
        say "${C_INK}Formspree — signups → your email${C_RST}"
        say "  1. Sign up free at ${C_BLU}https://formspree.io${C_RST} and create a new form."
        say "  2. Copy its endpoint — it looks like ${C_DIM}https://formspree.io/f/abcdxyz${C_RST}."
        say "  3. Your very first real submit triggers a one-time confirm email — click it."
        say ""
        ask SIGNUP_ENDPOINT "Paste your Formspree endpoint (or leave blank to add later)" "$SIGNUP_ENDPOINT"
      fi
      # Formspree returns proper CORS — optimistic should be false unless the user overrode it.
      if [ "$OPTIMISTIC_EXPLICIT" != "1" ]; then OPTIMISTIC_SUBMIT="false"; fi
      ;;
  esac

  # Rewrite the config now that the endpoint/optimistic flag are known.
  write_config

  if [ -z "$SIGNUP_ENDPOINT" ]; then
    warn "No endpoint set yet — the page will show the 'email the coach' fallback until you add one."
    say  "Re-run ${C_INK}./install.sh${C_RST} anytime (or edit ${C_INK}$CONFIG_OUT${C_RST}) to plug it in."
  fi

  # ── Publish the static files ───────────────────────────────────────────────────────────────
  banner "Put the page online" "$C_GRN"
  say "Your whole site is this folder: ${C_INK}$REPO_ROOT/apps/web${C_RST}"
  say "It's two files (index.html + your config.js). Any static host works — here are the friendly ones:"
  say ""
  say "  ${C_INK}Cloudflare Pages / Netlify (drag-and-drop, free HTTPS):${C_RST}"
  say "    • Netlify Drop: open ${C_BLU}https://app.netlify.com/drop${C_RST} and drag the ${C_INK}apps/web${C_RST} folder onto it."
  say "    • Cloudflare Pages: create a project, set the build output directory to ${C_INK}apps/web${C_RST}."
  say "    → You get a free ${C_DIM}*.pages.dev / *.netlify.app${C_RST} URL. Add a custom domain later in their dashboard."
  say ""
  say "  ${C_INK}GitHub Pages:${C_RST} push the repo, Settings → Pages → serve from ${C_INK}/apps/web${C_RST}."
  say ""
  say "  ${C_DIM}(Drag-drop tip: because config.js is git-ignored, dragging the folder is the simplest way to"
  say "   ship YOUR config with it. A repo-connected deploy needs config.js committed on a private branch.)${C_RST}"
  say ""

  # Offer a genuine local preview so a total beginner can see it work before publishing anywhere.
  if [ "$DRY_RUN" != "1" ] && confirm "Want to preview it locally in your browser right now?" "n"; then
    open_local_preview
  fi

  print_next_steps "email"
}

# Try to open apps/web/index.html locally, or serve it briefly on a throwaway high port.
open_local_preview() {
  local index="$REPO_ROOT/apps/web/index.html"
  if command -v python3 >/dev/null 2>&1; then
    say "Serving ${C_INK}apps/web${C_RST} at ${C_BLU}http://localhost:8765${C_RST} — press ${C_INK}Ctrl-C${C_RST} to stop."
    ( cd "$REPO_ROOT/apps/web" && python3 -m http.server 8765 ) || true
  else
    say "Opening the file directly in your browser…"
    if command -v open >/dev/null 2>&1; then open "$index" || true       # macOS
    elif command -v xdg-open >/dev/null 2>&1; then xdg-open "$index" || true  # Linux
    else say "Open this file in your browser: ${C_INK}$index${C_RST}"; fi
  fi
}

# ════════════════════════════════════════════════════════════════════════════════════════════
#  PATH B — Docker Compose  (self-host, own your data)  [v1, fully implemented]
# ════════════════════════════════════════════════════════════════════════════════════════════

# Resolve the compose command once (plugin `docker compose` vs legacy `docker-compose`).
compose_cmd() {
  if docker compose version >/dev/null 2>&1; then printf 'docker compose'
  elif command -v docker-compose >/dev/null 2>&1; then printf 'docker-compose'
  else return 1; fi
}

# A short URL-safe random token (portable across macOS/Linux). Empty string if /dev/urandom is missing.
rand_token() {
  LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom 2>/dev/null | head -c 20 || true
}

# Echo 1 (run the built-in backend) or 0 (static + form service). Prompts to stderr so stdout is clean.
resolve_backend() {
  case "$USE_BACKEND" in
    1) printf 1; return ;;
    0) printf 0; return ;;
  esac
  if [ "$NONINTERACTIVE" = "1" ] || [ -z "$TTY" ]; then printf 0; return; fi
  {
    say ""
    say "Two flavors of self-host:"
    say "  ${C_GRN}1)${C_RST} ${C_INK}Own your data${C_RST} — run the built-in backend: every signup saved to ${C_INK}SQLite on this box${C_RST},"
    say "     with a private roster page. No third-party form service. ${C_DIM}(recommended)${C_RST}"
    say "  ${C_BLU}2)${C_RST} ${C_INK}Just serve the site${C_RST} — point signups at a form service / your own webhook."
  } >&2
  local pick=""; ask pick "Which one" "1"
  case "$(lc "$pick")" in 2|site|static|form|"just the site") printf 0 ;; *) printf 1 ;; esac
}

# Roster login for the backend. Defaults to coach / a strong generated password.
collect_backend_creds() {
  [ -n "$ROSTER_USER" ] || ROSTER_USER="coach"
  ask ROSTER_USER "Roster login username" "$ROSTER_USER"
  if [ -z "$ROSTER_PASS" ]; then ROSTER_PASS="$(rand_token)"; fi
  [ -n "$ROSTER_PASS" ] || ROSTER_PASS="lego-$(date +%s)"   # ultra-fallback if /dev/urandom was unavailable
  ask ROSTER_PASS "Roster password (Enter to keep the strong generated one)" "$ROSTER_PASS"
}

# Shared by the box paths (Compose + DO Droplet): decide backend vs form-service and set the endpoint.
prepare_signup_destination() {
  RESOLVED_BACKEND="$(resolve_backend)"
  if [ "$RESOLVED_BACKEND" = "1" ]; then
    SIGNUP_ENDPOINT="/api/signup"
    if [ "$OPTIMISTIC_EXPLICIT" != "1" ]; then OPTIMISTIC_SUBMIT="false"; fi
    collect_backend_creds
    ok "Own-your-data backend: signups → SQLite on your box (signupEndpoint=/api/signup)."
  else
    if [ -z "$SIGNUP_ENDPOINT" ]; then
      say "Where should signups go? Point at a form service now, or add your own webhook/API later"
      say "by editing ${C_INK}$CONFIG_OUT${C_RST}."
      ask SIGNUP_ENDPOINT "Signup endpoint (Formspree URL / your webhook / blank for now)" "$SIGNUP_ENDPOINT"
    fi
  fi
}

# Write the services/api stack .env (SITE_DOMAIN + roster creds + email placeholders). Backs up any existing.
write_backend_env() {
  local envfile="$1"
  if [ -f "$envfile" ]; then
    local bak="$envfile.bak.$(date +%Y%m%d%H%M%S).$$"; cp "$envfile" "$bak"; warn "Existing $envfile saved to: $bak"
  fi
  cat > "$envfile" <<EOF
# Generated by install.sh on $(date -u +%Y-%m-%dT%H:%M:%SZ). Own-your-data stack (services/api).
# git-ignored — holds your roster password. Never commit it.
SITE_DOMAIN=$SITE_DOMAIN
ROSTER_USER=$ROSTER_USER
ROSTER_PASS=$ROSTER_PASS
COACH_EMAIL=$TEAM_COACH_EMAIL
# Optional email notifications — fill these to get an email per signup (see services/api/.env.example):
SMTP_HOST=
SMTP_PORT=587
SMTP_USER=
SMTP_PASS=
SMTP_FROM=
SMTP_TLS=1
EOF
  ok "Wrote $envfile"
}

deploy_compose() {
  banner "Path: Self-host with Docker Compose (own your data)" "$C_BLU"
  say "Caddy serves your site with automatic HTTPS. One command, and the signup data stays on"
  say "your own box (a Raspberry Pi, NAS, old laptop, or a cheap VPS)."
  say ""

  if ! command -v docker >/dev/null 2>&1; then
    err "Docker isn't installed on this machine."
    say "Install Docker Desktop (Mac/Windows) or Docker Engine (Linux): ${C_BLU}https://docs.docker.com/get-docker/${C_RST}"
    say ""
    if confirm "No Docker handy — switch to the no-server email path instead?" "y"; then
      deploy_email; return
    fi
    warn "Leaving the Docker path set up on disk; install Docker, then run the commands below yourself."
  fi

  # Own-your-data backend, or static site + form service?
  prepare_signup_destination
  write_config

  # Domain for Caddy's auto-HTTPS.
  say ""
  say "Caddy needs a domain to get a real HTTPS certificate. Leave it as ${C_INK}localhost${C_RST} to test"
  say "locally first (self-signed cert), or enter your domain (it must resolve to this box)."
  ask SITE_DOMAIN "Domain for the site" "$SITE_DOMAIN"

  # Pick the stack + write its env. Backend → services/api (bundled Caddy+api); static → deploy/compose.
  local stackdir envfile
  if [ "$RESOLVED_BACKEND" = "1" ]; then
    stackdir="$REPO_ROOT/services/api"
    envfile="$stackdir/.env"
    write_backend_env "$envfile"
  else
    stackdir="$REPO_ROOT/deploy/compose"
    envfile="$COMPOSE_ENV_OUT"
    local envdir; envdir="$(dirname "$envfile")"
    [ -d "$envdir" ] || die "Compose folder not found: $envdir"
    cat > "$envfile" <<EOF
# Generated by install.sh on $(date -u +%Y-%m-%dT%H:%M:%SZ).
# Domain Caddy serves + auto-provisions HTTPS for. "localhost" = local test cert.
SITE_DOMAIN=$SITE_DOMAIN
EOF
    ok "Wrote $envfile (SITE_DOMAIN=$SITE_DOMAIN)"
  fi

  local cc; if ! cc="$(compose_cmd)"; then
    warn "No compose CLI found — validation skipped. Install Docker Compose to bring the site up."
    compose_roster_note; print_next_steps "compose"; return
  fi

  # Always validate the compose file — cheap, needs no daemon, catches typos before 'up'.
  say ""
  say "Validating the Compose configuration…"
  if $cc -f "$stackdir/docker-compose.yml" --env-file "$envfile" config >/dev/null; then
    ok "docker compose config is valid."
  else
    die "The Compose configuration failed to validate. Check Docker and the files under $stackdir/."
  fi

  local reldir="${stackdir#$REPO_ROOT/}"
  if [ "$DRY_RUN" = "1" ]; then
    say ""
    dim "[dry-run] Skipping 'docker compose up -d'. To go live, run:"
    say  "    cd $reldir && $cc up -d"
    compose_roster_note; print_next_steps "compose"; return
  fi

  say ""
  warn "This binds ports 80 and 443 on this machine. If something else uses them (another web"
  warn "server, Traefik…), stop that first or put Caddy behind your existing reverse proxy."
  if [ "$RESOLVED_BACKEND" = "1" ]; then
    say "${C_DIM}(First run builds the tiny backend image — give it a few extra seconds.)${C_RST}"
  fi
  if confirm "Start the site now with '$cc up -d'?" "y"; then
    ( cd "$stackdir" && $cc --env-file .env up -d )
    ok "Site is up. Watch it get a cert with:  cd $reldir && $cc logs -f caddy"
  else
    say "No problem. When you're ready:  ${C_INK}cd $reldir && $cc up -d${C_RST}"
  fi
  compose_roster_note
  print_next_steps "compose"
}

# Print where the private roster lives, when the backend is in play.
compose_roster_note() {
  [ "$RESOLVED_BACKEND" = "1" ] || return 0
  say ""
  ok "Your signups live on this box (SQLite). Private roster:"
  say "    ${C_INK}https://$SITE_DOMAIN/api/roster${C_RST}   ${C_DIM}(login: $ROSTER_USER / the password you set)${C_RST}"
  say "    ${C_DIM}CSV export: add ?format=csv · to get an email per signup, fill SMTP_* in $REPO_ROOT/services/api/.env${C_RST}"
}

# ════════════════════════════════════════════════════════════════════════════════════════════
#  PATH C — DigitalOcean  [one-click Droplet via doctl + cloud-init; manual runbook as fallback]
# ════════════════════════════════════════════════════════════════════════════════════════════
#
#  The one-click is "the Compose path, in the cloud": we create a cheap Droplet whose cloud-init
#  installs Docker, clones the kit, drops in the coach's config.js, and runs the same Caddy
#  auto-HTTPS stack as PATH B. So the droplet owns its data and gets real HTTPS on its own.
#  If doctl isn't installed/authenticated (or the coach declines), we fall back to the runbook.

# The domain Caddy serves on the droplet. A real domain → auto Let's Encrypt HTTPS; blank/localhost
# → ":80" so the site answers on the raw droplet IP over HTTP for immediate testing.
do_compose_domain() {
  if [ -z "$SITE_DOMAIN" ] || [ "$SITE_DOMAIN" = "localhost" ]; then printf ':80'; else printf '%s' "$SITE_DOMAIN"; fi
}

# Best-effort monthly price for a size slug (empty if doctl can't tell us).
do_size_price() {
  doctl compute size list --format Slug,PriceMonthly --no-header 2>/dev/null \
    | awk -v s="$1" '$1==s{print $2; exit}'
}

# Write a cloud-init user-data file that stands the whole site up on first boot.
# $1 = output path, $2 = the SITE_DOMAIN value Caddy should use on the droplet.
do_build_cloud_init() {
  local out="$1" csd="$2" cfg_b64 env_b64 subdir envtext stackdesc
  cfg_b64="$(base64 < "$CONFIG_OUT" | tr -d '\n')"
  if [ "$RESOLVED_BACKEND" = "1" ]; then
    subdir="services/api"
    stackdesc="the own-your-data stack (Caddy + SQLite signup backend)"
    envtext="$(printf 'SITE_DOMAIN=%s\nROSTER_USER=%s\nROSTER_PASS=%s\nCOACH_EMAIL=%s\nSMTP_PORT=587\nSMTP_TLS=1\n' \
      "$csd" "$ROSTER_USER" "$ROSTER_PASS" "$TEAM_COACH_EMAIL")"
  else
    subdir="deploy/compose"
    stackdesc="the Caddy auto-HTTPS static stack (deploy/compose)"
    envtext="$(printf 'SITE_DOMAIN=%s\n' "$csd")"
  fi
  env_b64="$(printf '%s' "$envtext" | base64 | tr -d '\n')"
  cat > "$out" <<EOF
#cloud-config
# Generated by the FIRST LEGO League Team Kit installer.
# Stands up the signup site on this droplet: installs Docker, clones the kit, drops in your
# config, and runs $stackdesc. Nothing personal is baked into the shipped kit.
package_update: true
packages:
  - git
  - curl
  - ca-certificates
write_files:
  - path: /root/lego-config.js
    encoding: b64
    permissions: '0644'
    content: $cfg_b64
  - path: /root/lego-compose.env
    encoding: b64
    permissions: '0600'
    content: $env_b64
runcmd:
  - [ sh, -c, "command -v docker >/dev/null 2>&1 || curl -fsSL https://get.docker.com | sh" ]
  - [ sh, -c, "git clone --depth 1 $REPO_URL /opt/lego-kit" ]
  - [ sh, -c, "install -m 0644 /root/lego-config.js /opt/lego-kit/apps/web/config.js" ]
  - [ sh, -c, "install -m 0600 /root/lego-compose.env /opt/lego-kit/$subdir/.env" ]
  - [ sh, -c, "cd /opt/lego-kit/$subdir && docker compose --env-file .env up -d" ]
EOF
}

# If the site's domain is one DigitalOcean manages, offer to point its A record at the droplet.
# $1 = droplet public IP. No-op (with a manual hint) when the domain isn't on DO.
do_maybe_create_dns() {
  local ip="$1" apex="" sub="" d=""
  [ -n "$SITE_DOMAIN" ] && [ "$SITE_DOMAIN" != "localhost" ] || return 0
  for d in $(doctl compute domain list --format Domain --no-header 2>/dev/null); do
    case "$SITE_DOMAIN" in
      "$d")     apex="$d"; sub="@" ;;
      *".$d")   apex="$d"; sub="${SITE_DOMAIN%.$d}" ;;
    esac
  done
  if [ -z "$apex" ]; then
    say "  ${C_INK}DNS:${C_RST} point an ${C_INK}A${C_RST} record for ${C_INK}$SITE_DOMAIN${C_RST} → ${C_INK}$ip${C_RST} at your registrar."
    say "       Caddy issues HTTPS automatically within ~1–2 min of that DNS resolving."
    return 0
  fi
  if confirm "Your domain '$apex' is on DigitalOcean — create the A record $SITE_DOMAIN → $ip now?" "y"; then
    if doctl compute domain records create "$apex" \
         --record-type A --record-name "$sub" --record-data "$ip" --record-ttl 300 >/dev/null 2>&1; then
      ok "DNS A record created: $SITE_DOMAIN → $ip (TTL 300s)."
    else
      warn "Couldn't create the record automatically (it may already exist). Check: doctl compute domain records list $apex"
    fi
  else
    say "  ${C_INK}DNS:${C_RST} add it yourself later — A record $SITE_DOMAIN → $ip."
  fi
}

# The 15-minute by-hand path (App Platform or Droplet), used when doctl isn't ready or is declined.
do_manual_runbook() {
  say "  ${C_INK}A) App Platform (static, easiest):${C_RST}"
  say "     • Push your repo to GitHub, then in DigitalOcean → Apps → Create App → pick the repo."
  say "     • Resource type: ${C_INK}Static Site${C_RST}. Output/source directory: ${C_INK}apps/web${C_RST}."
  say "     • Deploy. You get a free ${C_DIM}*.ondigitalocean.app${C_RST} URL with HTTPS. Add a domain later."
  say ""
  say "  ${C_INK}B) Droplet + Docker Compose (own the box):${C_RST}"
  say "     • Create the cheapest Ubuntu Droplet, point your domain's A record at its IP."
  say "     • SSH in, install Docker, ${C_INK}git clone${C_RST} this kit, then run ${C_INK}./install.sh${C_RST} there"
  say "       and choose the ${C_INK}Docker Compose${C_RST} path with your real domain."
  say ""
  say "Full runbook: ${C_DIM}$REPO_ROOT/docs/deploy/digitalocean.md${C_RST}"
}

# Create the droplet and report back. Assumes doctl is installed + authenticated.
do_provision_droplet() {
  local ci; ci="$(mktemp "${TMPDIR:-/tmp}/lego-cloud-init.XXXXXX")" || die "Couldn't create a temp file for cloud-init."
  do_build_cloud_init "$ci" "$(do_compose_domain)"
  ok "Wrote cloud-init user-data → $ci"

  # Attach the account's SSH keys (best effort) so the coach can log in for maintenance.
  local sshkeys; sshkeys="$(doctl compute ssh-key list --format ID --no-header 2>/dev/null | tr '\n' ',' | sed 's/,$//')"
  local price; price="$(do_size_price "$DO_SIZE")"

  banner "Ready to create your DigitalOcean droplet" "$C_YEL"
  say "  name:    ${C_INK}$DO_DROPLET_NAME${C_RST}"
  say "  region:  ${C_INK}$DO_REGION${C_RST}"
  say "  size:    ${C_INK}$DO_SIZE${C_RST}${price:+  ${C_DIM}(~\$$price/mo)${C_RST}}"
  say "  image:   ${C_INK}$DO_IMAGE${C_RST}"
  say "  domain:  ${C_INK}${SITE_DOMAIN:-<none — serves on the droplet IP over HTTP>}${C_RST}"
  [ -z "$sshkeys" ] && warn "No SSH keys found on your DO account — DigitalOcean will email you a root password. (Add a key with: doctl compute ssh-key import)"
  say ""
  warn "This creates a PAID droplet on your DigitalOcean account — it bills until you destroy it (doctl compute droplet delete $DO_DROPLET_NAME)."
  if [ "$NONINTERACTIVE" != "1" ] && ! confirm "Create it now?" "y"; then
    say "No problem — nothing was created. Your config + cloud-init are ready when you are:"
    say "    ${C_INK}doctl compute droplet create $DO_DROPLET_NAME --region $DO_REGION --size $DO_SIZE --image $DO_IMAGE --user-data-file $ci --wait${C_RST}"
    print_next_steps "digitalocean"; return
  fi

  say ""
  say "Creating the droplet (~30–60s)…"
  local -a dargs
  dargs=(compute droplet create "$DO_DROPLET_NAME" \
         --region "$DO_REGION" --size "$DO_SIZE" --image "$DO_IMAGE" \
         --user-data-file "$ci" --wait --format PublicIPv4 --no-header)
  [ -n "$sshkeys" ] && dargs+=(--ssh-keys "$sshkeys")

  local ip=""
  if ! ip="$(doctl "${dargs[@]}")"; then
    err "doctl couldn't create the droplet (see the error above)."
    say "Your config + cloud-init are ready ($ci). Fix the issue (often: region/size/image slug, or quota) and retry."
    print_next_steps "digitalocean"; return
  fi
  ip="$(printf '%s' "$ip" | tr -d '[:space:]')"

  if [ -z "$ip" ]; then
    warn "Droplet created, but I couldn't read its public IP. Find it with:  doctl compute droplet list"
    print_next_steps "digitalocean"; return
  fi

  ok "Droplet is up! Public IP: ${C_INK}$ip${C_RST}"
  say ""
  do_maybe_create_dns "$ip"
  say ""
  say "First boot runs cloud-init (Docker install + site start) — give it ~2–3 minutes."
  if [ -n "$SITE_DOMAIN" ] && [ "$SITE_DOMAIN" != "localhost" ]; then
    say "Then your site is live at ${C_INK}https://$SITE_DOMAIN${C_RST} (HTTPS auto-issues once DNS resolves)."
  else
    say "Test it now at ${C_INK}http://$ip${C_RST}. Add a domain later (re-run with --domain) for HTTPS."
  fi
  say "  ${C_DIM}Watch it come up:  ssh root@$ip 'cloud-init status --wait && docker ps'${C_RST}"
  if [ "$RESOLVED_BACKEND" = "1" ]; then
    say ""
    ok "Own-your-data backend is on this droplet. Private roster (once it's up):"
    local rhost="${SITE_DOMAIN:-$ip}"
    say "    ${C_INK}https://$rhost/api/roster${C_RST}   ${C_DIM}(login: $ROSTER_USER / the password you set)${C_RST}"
  fi
  print_next_steps "digitalocean"
}

# doctl readiness: echoes "" when installed + authenticated, else a short reason.
do_doctl_reason() {
  if ! command -v doctl >/dev/null 2>&1; then printf "doctl isn't installed"; return; fi
  if ! doctl account get >/dev/null 2>&1; then printf "doctl isn't authenticated (run: doctl auth init)"; return; fi
  printf ''
}

# Echo droplet | app. Prompts to stderr.
do_target_menu() {
  case "$DO_TARGET" in droplet|app) printf '%s' "$DO_TARGET"; return ;; esac
  if [ "$NONINTERACTIVE" = "1" ] || [ -z "$TTY" ]; then printf 'droplet'; return; fi
  {
    say ""
    say "Two DigitalOcean styles:"
    say "  ${C_GRN}1)${C_RST} ${C_INK}Droplet${C_RST} — a small server we provision; owns its data, can run the built-in backend. ${C_DIM}(recommended)${C_RST}"
    say "  ${C_BLU}2)${C_RST} ${C_INK}App Platform${C_RST} — free static hosting built from your GitHub repo; no server (and no backend)."
  } >&2
  local pick=""; ask pick "Which one" "1"
  case "$(lc "$pick")" in 2|app|platform|"app platform") printf 'app' ;; *) printf 'droplet' ;; esac
}

# Best-effort "owner/name" from the repo's origin remote.
infer_github_repo() {
  local url; url="$(git -C "$REPO_ROOT" remote get-url origin 2>/dev/null)" || return 1
  case "$url" in
    git@github.com:*)      url="${url#git@github.com:}" ;;
    https://github.com/*)  url="${url#https://github.com/}" ;;
    ssh://git@github.com/*) url="${url#ssh://git@github.com/}" ;;
    *) return 1 ;;
  esac
  printf '%s' "${url%.git}"
}

# PATH C-2 — App Platform (static site from a GitHub repo). doctl-driven, static-only (no backend).
deploy_do_app() {
  banner "Path: DigitalOcean App Platform (static site)" "$C_YEL"
  say "App Platform builds your site straight from a GitHub repo and hosts it free with HTTPS —"
  say "no server to keep running. Two things it needs that a Droplet doesn't:"
  say "  1) your site in a ${C_INK}GitHub repo${C_RST} on your account, and"
  say "  2) that repo ${C_INK}connected to DigitalOcean${C_RST} once (Apps → GitHub — a 2-click OAuth)."
  say ""
  warn "App Platform builds from git, so your ${C_INK}config.js must be committed to that repo${C_RST} (it's"
  warn "git-ignored by default). It holds only public info (your coach email). Simplest: keep the repo"
  warn "private and commit it — ${C_INK}git add -f apps/web/config.js && git commit -m config && git push${C_RST}"
  say ""

  # App Platform static sites can't run the backend — signups go to a form service / webhook.
  if [ "$RESOLVED_BACKEND" = "1" ]; then
    warn "The built-in backend needs a server, so it isn't available on App Platform. Falling back to a form service/webhook for signups."
    SIGNUP_ENDPOINT=""; RESOLVED_BACKEND=0
  fi
  if [ -z "$SIGNUP_ENDPOINT" ]; then
    ask SIGNUP_ENDPOINT "Signup endpoint (Formspree URL / your webhook / blank for now)" "$SIGNUP_ENDPOINT"
  fi
  write_config

  if [ -z "$DO_APP_REPO" ]; then
    local inferred; inferred="$(infer_github_repo || true)"
    ask DO_APP_REPO "Your GitHub repo (owner/name) that has apps/web" "${inferred:-your-user/first-lego-league-team-kit}"
  fi
  ask DO_APP_BRANCH "Branch to deploy" "${DO_APP_BRANCH:-main}"

  local slug; slug="$(printf '%s' "$TEAM_TOWN" | tr '[:upper:] ' '[:lower:]-' | tr -dc 'a-z0-9-' | head -c 24)"
  local appname="lego-league"; [ -n "$slug" ] && appname="lego-league-$slug"

  local spec; spec="$(mktemp "${TMPDIR:-/tmp}/lego-app-spec.XXXXXX")" || die "Couldn't create a temp file for the app spec."
  cat > "$spec" <<EOF
name: $appname
static_sites:
  - name: web
    github:
      repo: $DO_APP_REPO
      branch: $DO_APP_BRANCH
      deploy_on_push: true
    source_dir: /apps/web
    catchall_document: index.html
EOF
  ok "Wrote App Platform spec → $spec  ${C_DIM}(repo: $DO_APP_REPO@$DO_APP_BRANCH)${C_RST}"

  local reason; reason="$(do_doctl_reason)"
  if [ -n "$reason" ] || [ "$DRY_RUN" = "1" ]; then
    say ""
    if [ -n "$reason" ]; then warn "Not deploying automatically: $reason."; fi
    [ "$DRY_RUN" = "1" ] && dim "[dry-run] Skipping 'doctl apps create'."
    say "When ready:  ${C_INK}doctl apps create --spec $spec --wait${C_RST}"
    say "Or by hand: DigitalOcean → Apps → Create App → your repo → Static Site, source dir ${C_INK}/apps/web${C_RST}."
    print_next_steps "digitalocean"; return
  fi

  say ""
  say "Creating the app (first build + deploy can take a few minutes)…"
  local appid=""
  if ! appid="$(doctl apps create --spec "$spec" --format ID --no-header --wait)"; then
    err "doctl couldn't create the app (see the error above)."
    say "Most common cause: this GitHub repo isn't connected to your DigitalOcean account yet."
    say "Fix once: DigitalOcean → Apps → Create App → GitHub → authorize, then re-run. Spec saved: $spec"
    print_next_steps "digitalocean"; return
  fi
  appid="$(printf '%s' "$appid" | tr -d '[:space:]')"
  ok "App created (id: $appid)."
  local url; url="$(doctl apps get "$appid" --format DefaultIngress --no-header 2>/dev/null | tr -d '[:space:]')"
  if [ -n "$url" ]; then ok "Live URL: ${C_INK}$url${C_RST}"; else say "Find your URL with: ${C_INK}doctl apps get $appid${C_RST}"; fi
  say "Add a custom domain later: DigitalOcean → Apps → your app → Settings → Domains."
  print_next_steps "digitalocean"
}

deploy_digitalocean() {
  banner "Path: DigitalOcean (cloud)" "$C_YEL"
  say "A ${C_INK}Droplet${C_RST} we provision with doctl (owns its data, Caddy auto-HTTPS — the cloud version of"
  say "the Docker path), or ${C_INK}App Platform${C_RST} static hosting built from your GitHub repo."
  say ""

  local target; target="$(do_target_menu)"
  if [ "$target" = "app" ]; then
    deploy_do_app; return
  fi

  # ── Droplet ────────────────────────────────────────────────────────────────
  # The droplet needs a signup destination — offer the built-in backend (same as Compose).
  prepare_signup_destination

  # Domain for Caddy's auto-HTTPS on the droplet. Treat the generic "localhost" default as blank here.
  say ""
  say "A domain lets the droplet get real HTTPS automatically. Leave it blank to test on the raw IP first."
  local domdefault="$SITE_DOMAIN"; [ "$domdefault" = "localhost" ] && domdefault=""
  ask SITE_DOMAIN "Domain for the site (blank = serve on the droplet IP over HTTP)" "$domdefault"
  write_config

  # Can we do the real one-click?
  local why; why="$(do_doctl_reason)"
  local can_auto=1; [ -n "$why" ] && can_auto=0

  if [ "$can_auto" = "1" ] && [ "$DRY_RUN" = "1" ]; then
    local ci; ci="$(mktemp "${TMPDIR:-/tmp}/lego-cloud-init.XXXXXX")" || die "Couldn't create a temp file for cloud-init."
    do_build_cloud_init "$ci" "$(do_compose_domain)"
    say ""
    dim "[dry-run] doctl is ready — skipping the real (billable) droplet create."
    dim "[dry-run] cloud-init user-data written to: $ci"
    print_next_steps "digitalocean"; return
  fi

  if [ "$can_auto" = "1" ]; then
    if [ "$NONINTERACTIVE" = "1" ] && [ "$DO_PROVISION" != "1" ]; then
      say ""
      dim "doctl is ready. Re-run with ${C_INK}--do-provision${C_RST} (or DO_PROVISION=1) to auto-create the droplet non-interactively."
      do_manual_runbook; print_next_steps "digitalocean"; return
    fi
    if [ "$NONINTERACTIVE" != "1" ]; then
      say ""
      if ! confirm "doctl is ready. Provision a droplet and deploy automatically now?" "y"; then
        say ""
        do_manual_runbook; print_next_steps "digitalocean"; return
      fi
    fi
    do_provision_droplet
    return
  fi

  # doctl not ready → guide + manual runbook.
  say ""
  warn "One-click auto-deploy needs DigitalOcean's doctl CLI: $why."
  say "Install + authenticate: ${C_BLU}https://docs.digitalocean.com/reference/doctl/how-to/install/${C_RST}"
  say "then ${C_INK}doctl auth init${C_RST}, and re-run ${C_INK}./install.sh --path digitalocean${C_RST} for the one-click."
  say ""
  say "Or do it by hand now (either option is ~15 minutes):"
  say ""
  do_manual_runbook
  if confirm "Prefer a path that finishes right now instead? Use the no-server email path?" "n"; then
    deploy_email; return
  fi
  print_next_steps "digitalocean"
}

# ════════════════════════════════════════════════════════════════════════════════════════════
#  PATH D — Your own reverse proxy (Traefik) + tunnel
#  [v1.1 scaffold: parameterized template, validated; NEVER defaults to anyone's personal domain]
# ════════════════════════════════════════════════════════════════════════════════════════════

deploy_traefik() {
  banner "Path: Your own Traefik reverse proxy + tunnel" "$C_RED"
  say "If you already run Traefik (with a Cloudflare Tunnel or open ports), this drops a tiny"
  say "nginx container onto your existing proxy network with the right labels. You bring the"
  say "domain and the network name — this kit never assumes anyone else's."
  say ""
  write_config

  local tdir="$REPO_ROOT/deploy/traefik"
  if [ ! -f "$tdir/docker-compose.yml" ]; then
    warn "The Traefik template isn't present at deploy/traefik/ — skipping generation."
    print_next_steps "traefik"; return
  fi

  ask SITE_DOMAIN "The domain YOU control for this site (e.g. signup.yourtown.org)" "$SITE_DOMAIN"
  local proxynet="proxy"
  ask proxynet "Name of your existing external Traefik network" "proxy"
  local resolver="letsencrypt"
  ask resolver "Your Traefik certresolver name (as configured in your Traefik)" "letsencrypt"

  local envfile="$tdir/.env"
  cat > "$envfile" <<EOF
# Generated by install.sh on $(date -u +%Y-%m-%dT%H:%M:%SZ).
# Parameterized Traefik path — your own infra. NEVER commit real domains you don't want public.
SITE_DOMAIN=$SITE_DOMAIN
PROXY_NETWORK=$proxynet
CERT_RESOLVER=$resolver
EOF
  ok "Wrote $envfile"

  local cc
  if cc="$(compose_cmd)"; then
    say "Validating the Traefik compose template…"
    if $cc -f "$tdir/docker-compose.yml" --env-file "$envfile" config >/dev/null 2>&1; then
      ok "Template validates."
    else
      warn "Template didn't validate standalone — that's expected if the external network"
      warn "'$proxynet' doesn't exist on THIS machine yet. It'll work on your Traefik host."
    fi
  fi

  # One-click when we're actually ON the Traefik host: the external proxy network exists here, so
  # Traefik is running on this machine and it's safe to bring the little nginx container up now.
  if [ "$DRY_RUN" != "1" ] && [ -n "$cc" ] && command -v docker >/dev/null 2>&1 \
     && docker network inspect "$proxynet" >/dev/null 2>&1; then
    say ""
    ok "Found the external network '$proxynet' on this machine — looks like your Traefik host."
    if confirm "Bring the site up now with '$cc up -d'?" "y"; then
      ( cd "$tdir" && $cc --env-file .env up -d )
      ok "Up. Traefik should route ${C_INK}https://$SITE_DOMAIN${C_RST} once it discovers the labels."
      say "Watch:  ${C_INK}cd deploy/traefik && $cc logs -f web${C_RST}"
      print_next_steps "traefik"; return
    fi
    say "No problem — start it whenever you're ready with the command below."
  fi

  say ""
  if [ "$DRY_RUN" = "1" ]; then dim "[dry-run] Not starting the Traefik service."; fi
  say "This path assumes your Traefik + tunnel are already running, so I won't start it here."
  say "On your Traefik host, from ${C_INK}deploy/traefik/${C_RST}:"
  say "    ${C_INK}docker network ls${C_RST}            ${C_DIM}# confirm your proxy network name${C_RST}"
  say "    ${C_INK}docker compose up -d${C_RST}"
  say ""
  say "Full runbook (including the Cloudflare Tunnel option): ${C_DIM}$tdir/README.md${C_RST}"
  print_next_steps "traefik"
}

# ════════════════════════════════════════════════════════════════════════════════════════════
#  Next-steps epilogue (per path) + the always-on privacy/trademark reminders.
# ════════════════════════════════════════════════════════════════════════════════════════════

print_next_steps() {
  local path="$1"
  banner "You're (almost) live — here's what's next" "$C_YEL"

  case "$path" in
    email)
      say "  ${C_GRN}1.${C_RST} Publish ${C_INK}apps/web${C_RST} to Netlify/Cloudflare/GitHub Pages (steps above). Copy your live URL."
      say "  ${C_GRN}2.${C_RST} Signups arrive ${C_INK}in your email${C_RST} (Formspree) or ${C_INK}your Google Sheet${C_RST} (Apps Script)."
      ;;
    compose)
      if [ "$SITE_DOMAIN" = "localhost" ]; then
        say "  ${C_GRN}1.${C_RST} You tested at ${C_INK}https://localhost${C_RST}. Re-run with your real domain to go public."
      else
        say "  ${C_GRN}1.${C_RST} Your live URL: ${C_INK}https://$SITE_DOMAIN${C_RST} (once DNS points here + a cert issues)."
      fi
      say "  ${C_GRN}2.${C_RST} Signups go wherever your ${C_INK}signupEndpoint${C_RST} points. Data + certs live on ${C_INK}your box${C_RST}."
      ;;
    *)
      say "  ${C_GRN}1.${C_RST} Follow the runbook above to finish going live, then copy your live URL."
      say "  ${C_GRN}2.${C_RST} Signups go wherever your ${C_INK}signupEndpoint${C_RST} points."
      ;;
  esac
  say "  ${C_GRN}3.${C_RST} ${C_INK}Point your flyer's QR code at that live URL${C_RST}, print it, and go recruit. 🧱"
  say "  ${C_GRN}4.${C_RST} Do one real test signup on your ${C_INK}phone${C_RST} before printing — then delete the test row."
  say ""
  say "${C_DIM}Privacy: the form collects a child's first name + grade and your contact info — the minimum"
  say "to reach a family. Tell parents where signups go, and delete them at season's end.${C_RST}"
  say "${C_DIM}Trademark: keep the footer disclaimer + the ® marks. FIRST® and LEGO® aren't ours; this is a"
  say "volunteer community project, not sponsored by or affiliated with FIRST, the LEGO Group, or the school.${C_RST}"
}

# ════════════════════════════════════════════════════════════════════════════════════════════
#  Welcome + CLI
# ════════════════════════════════════════════════════════════════════════════════════════════

print_welcome() {
  [ "$NONINTERACTIVE" = "1" ] && return 0
  printf '%s' "$C_YEL$C_INK"
  cat <<'ART'

        ┌──┬──┬──┬──┐   FIRST® LEGO® League — Team Kit
        │◉ │◉ │◉ │◉ │   turnkey installer
        └──┴──┴──┴──┘
ART
  printf '%s' "$C_RST"
  say "Hey there 👋 — you're about to stand up a signup site for your team. It takes a couple of"
  say "minutes: answer a few questions, pick how you want to host it, and you'll be ready to recruit."
  say "No coding. Press ${C_INK}Enter${C_RST} to accept the smart default at any prompt. Let's build. 🧱🤖"
}

kit_version() {
  if command -v git >/dev/null 2>&1 && [ -n "$REPO_ROOT" ] && git -C "$REPO_ROOT" rev-parse >/dev/null 2>&1; then
    git -C "$REPO_ROOT" describe --tags --always 2>/dev/null || printf 'v0.1.0-dev'
  else
    printf 'v0.1.0-dev'
  fi
}

usage() {
  cat <<EOF
${C_YEL}${C_INK}FIRST LEGO League Team Kit — installer${C_RST}

Collects your team's details, writes apps/web/config.js, and deploys your signup site.

${C_INK}USAGE${C_RST}
  ./install.sh [options]
  curl -fsSL <raw-url>/install.sh | bash        # will offer to clone the repo first

${C_INK}OPTIONS${C_RST}
  -h, --help                 Show this help and exit
  -V, --version              Print the kit version and exit
  -y, --yes, --non-interactive
                             Don't prompt; use flags/env/defaults (great for scripts + testing)
      --path <name>          Hosting path: email | compose | digitalocean | traefik
      --dry-run              Prepare + validate everything, but DON'T run the live action
                             (no 'docker compose up', no browser). Safe for testing.
      --config-out <file>    Where to write config.js  (default: apps/web/config.js)
      --compose-env <file>   Where to write the Compose .env (default: deploy/compose/.env)

${C_INK}TEAM FIELDS${C_RST} (flags override matching env vars; both are optional)
      --town <s>             TEAM_TOWN            --region <s>        TEAM_REGION
      --school <s>           TEAM_SCHOOL          --coach-name <s>    TEAM_COACH_NAME
      --coach-email <s>      TEAM_COACH_EMAIL     --spots <n>         TEAM_SPOTS
      --cost <s>             TEAM_COST            --season-label <s>  TEAM_SEASON_LABEL
      --season-name <s>      TEAM_SEASON_NAME
      --endpoint <url>       SIGNUP_ENDPOINT      --optimistic <b>    OPTIMISTIC_SUBMIT
      --site-url <url>       SITE_URL             --domain <s>        SITE_DOMAIN
      --form-service <s>     FORM_SERVICE         (email path: formspree | google)

${C_INK}OWN-YOUR-DATA BACKEND${C_RST} (box paths — Docker Compose + DigitalOcean Droplet)
      --backend / --no-backend   Run the built-in SQLite signup backend (services/api), or don't
      --roster-user <s>      ROSTER_USER (default coach)   --roster-pass <s>  ROSTER_PASS (default: generated)

${C_INK}DIGITALOCEAN${C_RST} (via doctl — needs doctl installed + 'doctl auth init')
      --do-droplet / --do-app    Pick the DO style: a Droplet (default) or App Platform static site
    Droplet (billable server; owns data; can run the backend):
      --do-provision         Actually create the droplet in non-interactive mode
      --do-region <s>        DO_REGION  (default nyc1)   --do-size <s>   DO_SIZE  (default s-1vcpu-1gb)
      --do-image <s>         DO_IMAGE   (default ubuntu-24-04-x64)
      --do-name <s>          DO_DROPLET_NAME (default lego-league)
    App Platform (free static hosting from your GitHub repo; no server/backend):
      --do-repo <owner/name> DO_APP_REPO (default: inferred from git origin)
      --do-branch <s>        DO_APP_BRANCH (default main)

${C_INK}EXAMPLES${C_RST}
  ./install.sh
  ./install.sh --yes --path email --town "Maplewood" --coach-email "you@example.com" \\
               --endpoint "https://formspree.io/f/abcdxyz"
  ./install.sh --yes --path compose --domain signup.mytown.org --dry-run
  ./install.sh --yes --path digitalocean --domain signup.mytown.org \\
               --endpoint "https://formspree.io/f/abcdxyz" --do-provision   # one-click cloud droplet

Everything the installer collects is about YOU (the coach). It never collects a child's info.
EOF
}

need_val() { [ -n "${2:-}" ] || die "Option '$1' needs a value."; }

parse_args() {
  while [ $# -gt 0 ]; do
    case "$1" in
      -h|--help)    usage; exit 0 ;;
      -V|--version) printf '%s\n' "$(kit_version)"; exit 0 ;;
      -y|--yes|--non-interactive) NONINTERACTIVE=1 ;;
      --dry-run)    DRY_RUN=1 ;;
      --path)          need_val "$1" "${2:-}"; PATH_CHOICE="$(lc "$2")"; shift ;;
      --config-out)    need_val "$1" "${2:-}"; CONFIG_OUT="$2"; shift ;;
      --compose-env)   need_val "$1" "${2:-}"; COMPOSE_ENV_OUT="$2"; shift ;;
      --town)          need_val "$1" "${2:-}"; TEAM_TOWN="$2"; shift ;;
      --region)        need_val "$1" "${2:-}"; TEAM_REGION="$2"; shift ;;
      --school)        need_val "$1" "${2:-}"; TEAM_SCHOOL="$2"; shift ;;
      --coach-name)    need_val "$1" "${2:-}"; TEAM_COACH_NAME="$2"; shift ;;
      --coach-email)   need_val "$1" "${2:-}"; TEAM_COACH_EMAIL="$2"; shift ;;
      --spots)         need_val "$1" "${2:-}"; TEAM_SPOTS="$2"; shift ;;
      --cost)          need_val "$1" "${2:-}"; TEAM_COST="$2"; shift ;;
      --season-label)  need_val "$1" "${2:-}"; TEAM_SEASON_LABEL="$2"; shift ;;
      --season-name)   need_val "$1" "${2:-}"; TEAM_SEASON_NAME="$2"; shift ;;
      --endpoint)      need_val "$1" "${2:-}"; SIGNUP_ENDPOINT="$2"; shift ;;
      --optimistic)    need_val "$1" "${2:-}"; OPTIMISTIC_SUBMIT="$2"; OPTIMISTIC_EXPLICIT=1; shift ;;
      --form-service)  need_val "$1" "${2:-}"; FORM_SERVICE="$(lc "$2")"; shift ;;
      --site-url)      need_val "$1" "${2:-}"; SITE_URL="$2"; shift ;;
      --domain)        need_val "$1" "${2:-}"; SITE_DOMAIN="$2"; shift ;;
      --do-provision)  DO_PROVISION=1 ;;
      --do-region)     need_val "$1" "${2:-}"; DO_REGION="$2"; shift ;;
      --do-size)       need_val "$1" "${2:-}"; DO_SIZE="$2"; shift ;;
      --do-image)      need_val "$1" "${2:-}"; DO_IMAGE="$2"; shift ;;
      --do-name)       need_val "$1" "${2:-}"; DO_DROPLET_NAME="$2"; shift ;;
      --do-app)        DO_TARGET="app" ;;
      --do-droplet)    DO_TARGET="droplet" ;;
      --do-repo)       need_val "$1" "${2:-}"; DO_APP_REPO="$2"; shift ;;
      --do-branch)     need_val "$1" "${2:-}"; DO_APP_BRANCH="$2"; shift ;;
      --backend)       USE_BACKEND=1 ;;
      --no-backend)    USE_BACKEND=0 ;;
      --roster-user)   need_val "$1" "${2:-}"; ROSTER_USER="$2"; shift ;;
      --roster-pass)   need_val "$1" "${2:-}"; ROSTER_PASS="$2"; shift ;;
      --) shift; break ;;
      -*) die "Unknown option: $1  (try ./install.sh --help)" ;;
      *)  die "Unexpected argument: $1  (try ./install.sh --help)" ;;
    esac
    shift
  done
}

# ════════════════════════════════════════════════════════════════════════════════════════════
#  Main
# ════════════════════════════════════════════════════════════════════════════════════════════

main() {
  parse_args "$@"
  init_tty
  ensure_repo_root "$@"

  # Resolve default output targets now that we know the repo root.
  [ -n "$CONFIG_OUT" ]      || CONFIG_OUT="$REPO_ROOT/apps/web/config.js"
  [ -n "$COMPOSE_ENV_OUT" ] || COMPOSE_ENV_OUT="$REPO_ROOT/deploy/compose/.env"

  print_welcome
  collect_team

  local choice="$PATH_CHOICE"
  [ -n "$choice" ] || choice="$(hosting_menu)"
  run_path "$choice"

  say ""
  ok "Done. Go find your ${TEAM_SPOTS:-eight} kids. 🧱🤖"
}

main "$@"
