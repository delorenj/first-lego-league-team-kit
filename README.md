# 🧱 LEGO League Team Kit

**A turnkey kit for starting a FIRST® LEGO® League team at your school — and filling the roster.**
A stylish mobile signup site, a print flyer, outreach emails, and a roster view. Edit one config
file, pick a deploy path, and a non-technical parent can be live in an afternoon — with an LLM to
walk them through it.

> Built by a kindergarten dad starting Clinton, NJ's first K–2 team. Everything's parameterized so
> it's *your* team in one file.

## What's in the box
- **Signup site** (`apps/web/`) — the neo-brutalist "BUILD. CODE. PLAY." page. Mobile-first (every visitor arrives via a flyer QR), config-driven, honeypot + validation, graceful email fallback.
- **Flyer** (`recruiting/flyer/`) — print-ready 8.5×11 with a QR to your signup page.
- **Outreach emails** (`recruiting/emails/`) — a school/HSA pitch and a co-coach invite, fill-in-the-blanks.
- **Deploy paths** (`deploy/`) — self-host with Docker Compose, one-click Vercel, or zero-backend static + form service.
- **Roster/admin + self-host API** — on the roadmap (`services/api/`, `AGENTS.md` §9).

## Quickstart
```bash
# 1. Make it your team
cp apps/web/config.example.js apps/web/config.js   # then edit: town, school, coach email, spots, cost…

# 2. Get it online — easiest self-host:
cd deploy/compose && cp .env.example .env          # set SITE_DOMAIN (or leave "localhost" to test)
docker compose up -d                               # → your site, with automatic HTTPS

# 3. Point the flyer QR at your live URL, print, and recruit.
```
**Not technical? Ask your LLM assistant to run the `deploy-team-site` skill** — it asks a couple of
questions and walks you through the best path, then tests a real signup with you.

| Deploy path | Owns your data? | Good for |
| --- | --- | --- |
| Static + form service | via Formspree/Google | no server, fastest, free |
| Docker Compose | ✅ your own box | data ownership, a Pi/NAS/VPS |
| Vercel | cloud (roadmap) | one-click cloud, no server |

Full guides: `.claude/skills/deploy-team-site/` · Config reference: `…/references/configure.md`

## Repo map
```
apps/web/          the signup site (index.html + config.js)
recruiting/        flyer + outreach emails
deploy/            compose / vercel + the deploy skill's home
services/api/      self-host backend (roadmap)
AGENTS.md          project charter for AI agents  ← start here if you're building
```

## Good-neighbor defaults
- **Kids' data:** the form asks for a child's *first name* and grade only — the minimum to contact a family. Keep it that way; tell parents where signups go and delete them at season's end.
- **Trademark:** every page ships the disclaimer *"not sponsored by or affiliated with FIRST, the LEGO Group, or the school"* and the ® marks. Leave them in. FIRST® and LEGO® belong to their owners.

## Building on this
`AGENTS.md` is the canonical charter (architecture, the signup-adapter contract, the design system,
the roadmap). Drive design + development through the **`master-builder`** agent. Formal planning runs
through BMAD (`_bmad-output/`); the board lives in Plane (`momo`).
