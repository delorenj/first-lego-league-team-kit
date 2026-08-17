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

It exists because Jarad is starting Clinton, NJ's first FIRST LEGO League team for the Fall 2026
(BIOGLOW) season and needed to fill an 8-kid roster. Clinton runs **FIRST LEGO League Explore —
grades 2–4 (ages 6–10), Founders Edition (LEGO SPIKE)**. (Note the 2026–27 restructure: "Discover" is
retired; the divisions are Explore grades 2–4 and Challenge grades 4–8 under Founders Edition, plus a
new Future Edition with K–2 and 3–8 tracks. The kit is **division-agnostic** — grade band, ages, and
grade buttons are config fields; K–2 is just the shipped example.) The original one-off — a flyer +
signup SPA wired to a personal n8n webhook — lives in `REMOTE_SESSION_CONTEXT/` (reference only, do not
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
| **Turnkey installer** (`install.sh`) — email & Compose full; **DO Droplet _and_ App Platform via `doctl`**; Traefik one-click on-host; **own-your-data backend** offered on box paths | ✅ real | `install.sh` + `docs/INSTALL.md` |
| Docker Compose deploy (Caddy + auto-HTTPS) | ✅ runnable today | `deploy/compose/` |
| Traefik reverse-proxy deploy (parameterized, BYO-infra) | ✅ template + runbook | `deploy/traefik/` |
| Deploy skill (triage + runbooks) | ✅ real, now fronts `install.sh` | `.claude/skills/deploy-team-site/` |
| Outreach email templates | ✅ drafts | `recruiting/emails/` |
| Print flyer (PDF) | ✅ static asset | `recruiting/flyer/` |
| Original prototype (do not ship) | 📦 archived | `REMOTE_SESSION_CONTEXT/` |
| **Project homepage** (GitHub Pages: marketing page + live `/demo/`) | ✅ real — "Eight Pistons" instruction-booklet design | `site/` + `.github/workflows/pages.yml` |
| Self-host signup API (SQLite + notify + roster) | ✅ **real** — zero-dep Python stdlib; own-your-data stack; wired into Compose + DO Droplet | `services/api/` |
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
parentName, parentEmail, parentPhone, childName, childGrade, helpWith, notes, source
```

`helpWith` is the **volunteer ask**: the "Can you help?" options a parent ticked, semicolon-separated
(`""` when none). It is one string, not repeated keys — Sheets/Formspree/n8n flatten repeats
differently, and the contract has to mean the same thing on every adapter. It exists because a new
team's co-coach is overwhelmingly likely to already be *in its own signup pool*: asking a parent who
has just committed their child converts far better than a cold ask months earlier. So the funnel
recruits kids first and harvests grown-ups from the same form. Options come from `helpOptions` in
`config.js` (`[]` hides the block); `services/api` highlights offering parents on the roster and flags
them in the notification subject.

Any destination that accepts that POST is a valid adapter. Three shipped tiers, easiest → most control:

1. **Form service** (zero backend) — Formspree / Getform / a Google Apps Script Web App. Emails the coach or appends to a Sheet. For the least technical user.
2. **Self-hosted API** (owns its data) — the `services/api` container: writes SQLite, optionally emails the coach, serves an authed neo-brutalist roster (HTML/CSV/JSON) with a delete button. **✅ real** — zero third-party deps (Python stdlib), same-origin behind Caddy (`/api/signup`), self-contained stack at `services/api/`. Offered by the installer on the Compose + DO-Droplet paths.
3. **Any webhook** — n8n, Zapier, Make, etc. (Jarad's current n8n is just this tier.)

**Do not break this contract.** New front-end fields → add to the payload *and* document them for
every adapter. The whole "swap deploy paths without touching the app" property depends on it.

### Config-driven
Everything team-specific comes from `window.TEAM_CONFIG` (`apps/web/config.js`). Generic FIRST LEGO
League copy stays hardcoded (it's identical for every team). A non-tech coach should never edit HTML.
Adding a knob = add a field to `config.js` + `config.example.js` + read it in `index.html` with a safe fallback.
**Division framing is config, not hardcoded:** `gradeBand`, `ageRange`, `audience`, `programName`,
`programKit`, `grades` (the grade buttons — **any number**, generated at runtime and wrapping), and
`spotsLine` (the line above the form) drive the Who/What/hero copy and the signup form. So one config
swaps the site between one Explore team (grades 2–4), a K–2 team, or a wide **demand-discovery** net
(e.g. `grades: ["K".."5th"]` + a "we're forming teams by grade" `spotsLine`) that measures interest
across grades before you commit to a division. Defaults describe the K–2 example.
`helpOptions` (+ optional `helpPrompt`) drives the **"Can you help?"** checkboxes above the submit
button — any number of options, `[]` to hide the block entirely.

### Recruiting kit (the full funnel)
Awareness → signup → confirmation → roster:
- **Flyer** (`recruiting/flyer/`) — print/QR, drives scans to the site.
- **Emails** (`recruiting/emails/`) — school/HSA(-or-PTO) pitch + co-coach ask, to get the flyer in front of families.
- **Social** (`recruiting/social/`) — Facebook/Nextdoor/text-chain post copy (3 lengths) to reach local families online.
- **Site** (`apps/web/`) — the 30-second mobile signup.
- **Roster/admin** — coach sees who signed up (`services/api` `/api/roster`, own-your-data path; hosted-form tiers see it in their dashboard).
- **Volunteer bench** — the same signup harvests grown-ups (`helpWith`). A coach with no co-coach is
  a stalled team, and cold-asking friends is the step that fails; the funnel is what unsticks it.

> **Program facts the kit has to respect** (verified against firstinspires.org + FIRST Mid-Atlantic,
> Aug 2026 — recheck before the next season, these move):
> - **Two screened lead coaches are mandatory**, not aspirational. As of 2026–27 a team cannot access
>   its youth roster until *both* Lead Coach 1 and 2 clear Youth Protection, and FMA won't let a team
>   register for an event unless FIRST shows it `Event Ready`. This is why `helpOptions` exists.
> - **Roster caps:** Explore traditional = 2 coaches + **2–6 kids**; Class Pack = up to 24 with one
>   facilitator (and *cannot* attend an official festival). `spots` is free-form, so a coach can
>   over-recruit deliberately — but the kit should never imply a seat it can't deliver.
> - **Cost, 2026–27 (corrected Aug 17 2026 — the old $150/$715 figures in this file were pre-restructure
>   and wrong):** Explore **traditional = $500**, which is registration **plus one SPIKE Essential set**;
>   **Class Pack = $2,900** (registration + six sets). The fee excludes shipping and **festival
>   registration**. FIRST recommends **one set per four students**, so a 6-kid team wants two. Coaches who
>   already own a SPIKE Essential still pay the bundled price unless a registration-only path exists —
>   flag that unknown rather than promising a cheaper number.
> - **Two editions run in parallel this season, and it's a division choice, not a kit upgrade.**
>   **Founders Edition** = the classic path: Explore (ages 6–10) on **SPIKE Essential** (or WeDo 2.0),
>   Challenge on SPIKE Prime (or EV3). **Future Edition** = the new path on **LEGO Education Computer
>   Science & AI** kits, with grade bands **K–2 and 3–8** and **no Explore division at all**. A coach
>   asking "which kit?" is really choosing an edition. Note SPIKE Essential was listed as available from
>   LEGO Education only **until 30 Jun 2026**, so existing sets hold their value.
> - **2026–27 BIOGLOW is the final FIRST LEGO League season**; LEGO Education relaunches it as
>   "LEGO League" in 2027. Don't write copy that assumes an open-ended FLL future — and note this is a
>   *recruiting asset*, since it makes a coach's ask a one-season commitment with a published end date.

> **Personal-fill convention:** the shipped files under `recruiting/**` are neutral templates with
> `{{placeholders}}`. A coach's real filled copies use a `*.filled.md` suffix and are **git-ignored**
> (like `config.js`) so no personal name/email/URL ever ships. Never bake real details into a template.
>
> **Deliver outreach where it gets sent, not where it gets read.** A filled email is only done when it's
> a **draft in the coach's mail client** — for Jarad, create it with the Gmail MCP (`create_draft`,
> never `send`; he edits and sends). The `.filled.md` is the durable copy and the place for *timing and
> strategy notes that don't belong in the email body* — who to send to, when, what not to say. Pasting
> email text into chat and stopping there leaves the last mile of work on the human. Same rule for any
> outreach artifact with a real destination: put it in the tool that sends it.

---

## 4. Repo layout

```
apps/web/              signup site — config-driven static SPA (index.html + config.js)
site/                  the KIT's own homepage (GitHub Pages; /demo/ = neutral apps/web) — see site/README.md
.github/workflows/     pages.yml — assembles site/ + apps/web → GitHub Pages
services/api/          self-host backend (SQLite + notify + roster) — ✅ real (Python stdlib)
recruiting/flyer/      print flyer PDF (+ generator)                          [generator = roadmap]
recruiting/emails/     outreach email templates (school/PTO pitch, co-coach ask)
recruiting/social/     social post copy (Facebook/Nextdoor/text) — 3 lengths
                       (coaches' real *.filled.md copies are git-ignored, per §3)
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
**Next — the turnkey installer (v0.1, headline goal): ✅ shipped (`install.sh`).** A standalone,
dependency-light (bash + coreutils + curl; Docker only for the self-host path) interactive installer a
non-technical parent runs *directly* — welcome → collect team basics → write `apps/web/config.js` →
hosting menu → run the chosen path → verify → next steps. Supports `--help`, a non-interactive/flags/env
mode (testable + power-user), `curl | bash` with clone-offer, and is idempotent (backs up an existing
config). Paths: **email/form-service** (Formspree or Google Apps Script — sets `optimisticSubmit`
correctly; then static-host guidance) and **Docker Compose** (writes `deploy/compose/.env`, `docker
compose up -d`) are **full end-to-end**. **DigitalOcean** is now a **one-click Droplet**: when `doctl`
is installed + authenticated the installer provisions a cheap Droplet whose **cloud-init** installs
Docker, clones the kit, injects the coach's `config.js`, and runs the same Caddy/Compose stack (so the
droplet owns its data + gets real HTTPS), attaches the account's SSH keys, shows the size price, and —
if the domain is DO-managed — creates the DNS `A` record; billable, so it always confirms first, and
falls back to the manual runbook when `doctl` is absent. **BYO Traefik + tunnel** (parameterized — never
`delo.sh`; `deploy/traefik/`) writes/validates the template and, **when run on the Traefik host** (the
external proxy network exists locally), offers a one-click `docker compose up`; from elsewhere it stays
a safe runbook. Clean extension seam intact (add a path = one `deploy_<name>()` + one line in
`run_path`). It generalizes the LLM-guided `deploy-team-site` skill into a no-LLM tool (the skill now
fronts it) and promotes the personal Traefik pattern into a shippable, parameterized option (§8).
The DigitalOcean path now offers **both** styles via `doctl`: a **Droplet** (billable server, owns its
data, can run the backend) and **App Platform** (`doctl apps create --spec` from the coach's GitHub repo,
free static hosting — needs a one-time GitHub↔DO OAuth it can't script, so it writes the spec + guides
when unconnected). *Remaining installer work:* the Vercel path.
**Then (v0.2):** ✅ **`services/api` done** — zero-dep Python-stdlib own-your-data adapter (SQLite +
optional coach email + authed HTML/CSV/JSON roster with delete), self-contained stack at `services/api/`,
offered by the installer on Compose + DO-Droplet. Still open: flyer generator (config → PDF w/ QR); strip
the Clinton example into `presets/` so first run is neutral.
**Distribution (v1):** ✅ public GitHub repo + Apache-2.0 license + warm `README`/`CONTRIBUTING`/`CODE_OF_CONDUCT` done. ✅ **Project homepage** (`site/`, GitHub Pages): the "Eight Pistons" instruction-booklet page — hero 2×4 roster brick, live demo iframe, parts manifest, baseplate deploy paths, safety notes, interactive Empty Roster, OG share card — for spreading the word (social/Reddit/LinkedIn/FIRST channels). Remaining: harden the quickstart, cut a tagged release, and make the installer cover every live path.

**Recommended immediate step:** installer covers email, Compose (± built-in backend), DigitalOcean
(Droplet + App Platform), and Traefik. `services/api` is the real own-your-data adapter. Next
highest-leverage work: (a) the **Vercel** path (the last stubbed deploy target), (b) the **flyer
generator** (config → PDF w/ QR) so the recruiting funnel is fully config-driven, and (c) a tagged
release + quickstart hardening. Drive through `master-builder`.

---

## 10. How to work here

- For design/architecture/build orchestration, drive through the **`master-builder`** agent (`.claude/agents/master-builder.md`) — it holds this vision, the design system, and the adapter contract.
- Verify changes against **mission 1**: does the Clinton instance still submit end-to-end and look right? Use the `run`/`verify` skills to actually exercise the flow, not just typecheck.
- Small, reversible, well-labeled changes. Update this charter when the product shape moves.
