# AGENTS.md — LEGO League Team Kit

> Agent charter for this repo. Root canonical instruction file — `.mise/scripts/link-agentfiles.sh`
> symlinks it to `CLAUDE.md` and `GEMINI.md`. Read this before touching anything.
> **When you make a decision that changes the product, the architecture, or a convention below,
> update this file in the same change.**

---

## 1. What this is

A **turnkey recruiting kit for starting a FIRST® LEGO® League team at your school** — a
config-driven signup site + print flyer + outreach emails + roster view that a **non-technical
parent or coach can deploy for their own town in an afternoon**, guided by an LLM.

It exists because Jarad is starting Clinton, NJ's first FIRST LEGO League K–2 team for the Fall
2026 (BIOGLOW) season and needed to fill an 8-kid roster. The original one-off — a flyer + signup
SPA wired to a personal n8n webhook — lives in `REMOTE_SESSION_CONTEXT/` (reference only, do not
ship). This repo **productizes** that into something anyone can redeploy.

**Two missions, in priority order:**
1. **Fill Jarad's Clinton team.** The Clinton instance must work end-to-end and look great. This is the acceptance test for everything.
2. **Make it a distributable DIY kit.** Any FLL coach clones the repo (or a release), edits one config file, runs the deploy skill, and has their own signup site live. It is a **self-deployable template, not a hosted SaaS.**

If a change helps mission 1 but blocks mission 2 (e.g. hardcoding "Clinton", a personal URL, or a
secret), it's wrong — parameterize it instead.

---

## 2. Status (keep current)

| Piece | State | Location |
| --- | --- | --- |
| Neo-brutalist signup SPA | ✅ productized, config-driven | `apps/web/` |
| Team config (the one file a coach edits) | ✅ real | `apps/web/config.js` |
| Clinton signup site — Jarad's live instance (mission 1) | ✅ **LIVE** at `lego.delo.sh` (personal homelab — see §6, dev/example-only) | `apps/web/` + git-ignored `config.js` |
| Docker Compose deploy (Caddy + auto-HTTPS) | ✅ runnable today | `deploy/compose/` |
| Deploy skill (triage + 3 runbooks) | ✅ real | `.claude/skills/deploy-team-site/` |
| Outreach email templates | ✅ drafts | `recruiting/emails/` |
| Print flyer (PDF) | ✅ static asset | `recruiting/flyer/` |
| Original prototype (do not ship) | 📦 archived | `REMOTE_SESSION_CONTEXT/` |
| Self-host signup API (SQLite + notify + roster) | 🗺️ roadmap | `services/api/` (stub) |
| Vercel serverless variant | 🗺️ roadmap | `deploy/vercel/` (stub) |
| Flyer generator (config → PDF w/ QR) | 🗺️ roadmap | `recruiting/flyer/` |
| Roster / admin view | 🗺️ roadmap | — |

`llr` (recency) is the tiebreaker on staleness — trust modified-time over this table if they disagree, then fix the table.

---

## 3. Product architecture

### The turnkey model
Ship a **template repo**, not a service. A coach gets it → edits `apps/web/config.js` → picks a
deploy path → is live. No account on Jarad's infra, ever. The distributed artifact must contain
**zero personal secrets, URLs, or PII** (Clinton values are the shipped *example*, clearly marked).

### Signup Adapter Contract — the core abstraction
The front end is backend-agnostic. It emits **one payload shape** to **one configurable endpoint**:

```
POST {config.signupEndpoint}   (Content-Type: application/x-www-form-urlencoded — dodges CORS preflight on purpose)
parentName, parentEmail, parentPhone, childName, childGrade, notes, source
```

Any destination that accepts that POST is a valid adapter. Three shipped tiers, easiest → most control:

1. **Form service** (zero backend) — Formspree / Getform / a Google Apps Script Web App. Emails the coach or appends to a Sheet. For the least technical user.
2. **Self-hosted API** (owns its data) — the `services/api` container: writes SQLite, notifies the coach, serves an authed roster. Reference path, pairs with Compose. *(roadmap)*
3. **Any webhook** — n8n, Zapier, Make, etc. (Jarad's current n8n is just this tier.)

**Do not break this contract.** New front-end fields → add to the payload *and* document them for
every adapter. The whole "swap deploy paths without touching the app" property depends on it.

### Config-driven
Everything team-specific comes from `window.TEAM_CONFIG` (`apps/web/config.js`). Generic FIRST LEGO
League copy stays hardcoded (it's identical for every team). A non-tech coach should never edit HTML.
Adding a knob = add a field to `config.js` + `config.example.js` + read it in `index.html` with a safe fallback.

### Recruiting kit (the full funnel)
Awareness → signup → confirmation → roster:
- **Flyer** (`recruiting/flyer/`) — print/QR, drives scans to the site.
- **Emails** (`recruiting/emails/`) — school/HSA pitch + co-coach ask, to get the flyer in front of families.
- **Site** (`apps/web/`) — the 30-second mobile signup.
- **Roster/admin** *(roadmap)* — coach sees who signed up.

---

## 4. Repo layout

```
apps/web/              signup site — config-driven static SPA (index.html + config.js)
services/api/          self-host backend (SQLite + notify + roster)          [roadmap stub]
recruiting/flyer/      print flyer PDF (+ generator)                          [generator = roadmap]
recruiting/emails/     outreach templates (school/HSA pitch, co-coach ask)
deploy/compose/        docker-compose + Caddyfile + .env.example — runnable today
deploy/vercel/         serverless variant                                     [roadmap stub]
.claude/agents/        master-builder (the design+dev orchestrator)
.claude/skills/        deploy-team-site (the DIY deploy skill)
REMOTE_SESSION_CONTEXT/ original prototype — reference, never shipped
_bmad*/ mise.toml       pjangler + BMAD + mise scaffolding (see §7)
```

---

## 5. Design system — "neo-brutalist LEGO brick"

The look is an asset. Keep it consistent everywhere (site, flyer, future admin).

- **Palette:** red `#D01012`, yellow `#F6BE00`, blue `#0057A6`, green `#00873E` (the four brick colors); ink `#1a1a2e`, muted `#55556b`, paper `#FFFDF7`. The four brick colors are config-overridable per team.
- **Type:** Poppins (weights 400–800). Chunky, tight headline tracking.
- **Motifs:** 3px solid ink borders; hard offset shadows (`5px 5px 0 var(--ink)`); 10–16px radii; the **stud strip** header; buttons that translate on hover/active (tactile "click"). Mobile-first, ~680px max content width.
- **Signature motion** (`apps/web/index.html`): an animated **brick-forge** hero that assembles bricks into a gear → laptop → sword on a 3D turntable; **isometric grade bricks** whose six studs piston up with an angled hop on select; ambient margin bricks (desktop); an intro build-in and a success brick-pop. All pure CSS/SVG (no WebGL), config-agnostic. **Two hard-won rules:** the forge's bricks must be built as *leaf faces directly under the single animated `preserve-3d` plane* — a *transform-animated* `preserve-3d` element flattens its *nested* `preserve-3d` children in Chrome; and prefer 2D-isometric (SVG + screen-space transforms) for interactive bits, both because it dodges that trap and because animated 3D can't be screenshot-verified headless.
- **Voice:** playful, parent-to-parent, concrete. "Grab a spot 🧱", "first come, first built", "Snapping bricks…". Never corporate.
- **Accessibility:** the brick palette on paper must stay legible; keep AA contrast for body text; every input has a real `<label>`. Every looping/decorative animation is gated behind `prefers-reduced-motion: reduce` — keep it that way when adding motion.

---

## 6. Deploy paths (for humans + LLMs)

Do **not** hand a non-technical coach raw commands. Route them through the **`deploy-team-site` skill**,
which triages by "do you want to own the data?" / "do you have a domain?" / "free?" and walks the chosen path:

- **Static + form service** — easiest, no backend. Static host (Cloudflare Pages / Netlify / GitHub Pages) + Formspree/Google.
- **Docker Compose** — portable, owns its data. `docker compose up` → Caddy auto-HTTPS. Runs on a Pi/NAS/old laptop. *(Jarad's reference path.)*
- **Vercel** — one-click cloud, managed DB. *(roadmap.)*

> **Jarad's own Clinton instance is NOT one of these three paths.** `lego.delo.sh` is served from
> Jarad's personal homelab via a global/personal `spa-host` skill (the "domipacolypse" one-off: an
> `nginx:alpine` container on the external Traefik `proxy` network + Cloudflare Tunnel wildcard
> `*.delo.sh`, Let's Encrypt via DNS-01). That skill lives outside this repo (`~/.claude/skills/spa-host/`)
> and its generated stack at `~/docker/stacks/websites/lego/`. Per §8, `spa-host`, `delo.sh`, Traefik,
> and the tunnel are **dev/example-only personal infra — never a template path.** A coach cloning the
> kit uses the three paths above and never touches `spa-host` or `delo.sh`.

---

## 7. Conventions (this is a pjangler CommonProject)

- **AGENTS.md is canonical.** Edit it, then run `mise run link-agentfiles` (or just re-enter the dir) to refresh the `CLAUDE.md`/`GEMINI.md` symlinks. Never edit `CLAUDE.md`/`GEMINI.md` directly.
- **mise** runs the show: `op inject -i .env.op > .env` on enter (secrets come from 1Password — never commit `.env`), agent-file linking, and codegraph if present.
- **Versioning:** managed by `mise run version:*` (semver across all version-bearing files). Bump on releases; never hand-edit version literals — derive from the manifest.
- **Tickets:** Plane board, workspace `33god`, identifier `LEGO` (`.project.json`). For board ops (triage, "what's next", record decisions) use the **`momo`** skill/agent — it runs the board; **master-builder** does the hands-on design+build. Keep those roles distinct.
- **BMAD** is installed (`_bmad/`, output → `_bmad-output/`). Formal product work flows through it: **product brief → PRD → architecture → epics/stories → dev**. No planning artifacts exist yet — the next formal step is a product brief/PRD for the kit.
- **Memory:** Hindsight bank is **`legofirst`**. Retain non-obvious decisions: `hindsight memory retain legofirst "…" --context <architecture|conventions|decisions>`.
- **Secrets:** check `.env` → `~/.config/zshyzsh/secrets.zsh` → 1Password before asking. Never bake a secret, personal URL, or real email into the shipped template — those are config.

---

## 8. Guardrails (non-negotiable)

- **Kids' data / privacy.** This form collects a **child's first name + grade and a parent's email/phone**. Minimize: collect only what a coach needs to contact a family — never a child's last name, DOB, address, or photo. The parent submits (implied consent). Every deployed instance must state where data goes and let the coach delete it. Form-service tiers send data to a third party — say so in the UI/skill. Treat this as the default posture, not an afterthought.
- **Trademark hygiene.** FIRST® and LEGO® are not ours. Every deployed instance must carry the disclaimer *"Organized by volunteer parents; not sponsored by or affiliated with FIRST, the LEGO Group, or the school"* and use ® on first mention. Never imply official sponsorship. This ships in `config.js`/the footer — keep it there.
- **No lock-in to personal infra.** `n8n.delo.sh`, `lego.delo.sh`, `jaradd@gmail.com`, `192.168.x`/`100.x` addresses are **Clinton-example / dev-only**. They must never be the default in shipped/template code — parameterize or use placeholders.
- **Honeypot + validation stay.** The bot honeypot and inline validation in the form are load-bearing; don't regress them.

---

## 9. Roadmap

**Now (v0 — done):** config-driven site with the animated brick design system, Compose deploy, LLM-guided deploy skill, emails, flyer asset. **Open-sourced (Apache-2.0)** as `delorenj/first-lego-league-team-kit` — a charity give-it-away kit: any parent takes everything (site, flyer, emails) and hosts it themselves.
**Next — the turnkey installer (v0.1, headline goal):** a **standalone, dependency-light interactive installer** (an `install.sh` / TUI a non-technical parent runs *directly* — "press enter, answer a couple of questions, it just works"), that offers and then *executes* the hosting choice for them: **self-host behind a reverse proxy (Traefik) + tunnel**, **DigitalOcean** (droplet / App Platform), other cloud, or **zero-backend static + a form service that just emails the coach the signup**. Containerized, no fuss to bring up. This generalizes today's LLM-guided `deploy-team-site` skill into something runnable *without* an LLM, and promotes the currently-personal Traefik pattern into a **parameterized, shippable** option (never Jarad's personal `delo.sh`/tunnel as a default — §8).
**Then (v0.2):** `services/api` (SQLite + coach email notification + `/api/roster`) as the reference own-your-data adapter; roster/admin view (authed); flyer generator (config → PDF w/ QR); strip the Clinton example into `presets/` so first run is neutral.
**Distribution (v1):** ✅ public GitHub repo + Apache-2.0 license + warm `README`/`CONTRIBUTING`/`CODE_OF_CONDUCT` done. Remaining: harden the quickstart, cut a tagged release, and make the installer cover every live path.

**Recommended immediate step:** build the interactive installer above — it's the thing that makes the kit genuinely turnkey for a non-technical coach. Drive it through `master-builder`.

---

## 10. How to work here

- For design/architecture/build orchestration, drive through the **`master-builder`** agent (`.claude/agents/master-builder.md`) — it holds this vision, the design system, and the adapter contract.
- Verify changes against **mission 1**: does the Clinton instance still submit end-to-end and look right? Use the `run`/`verify` skills to actually exercise the flow, not just typecheck.
- Small, reversible, well-labeled changes. Update this charter when the product shape moves.
