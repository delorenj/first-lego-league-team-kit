---
name: deploy-team-site
description: >-
  Get a FIRST LEGO League team signup site online — for a non-technical parent or coach, guided by
  an LLM. Use when someone wants to deploy, publish, host, launch, or "put online" the signup page /
  team site, go live, point a domain at it, or choose between self-hosting (Docker Compose), a
  one-click cloud host (Vercel), or a zero-backend static + form-service setup. Triages by data
  ownership / domain / cost, then walks the chosen path step by step and verifies a real test signup.
---

# Deploy your team signup site

You are helping a parent or coach — **possibly non-technical** — get their LEGO League signup site
live. Be concrete, go **one step at a time**, and **verify each step before moving on**. Prefer
copy-paste commands and screenshots-in-words over jargon. When something can go wrong, say so and how
to check. Never assume they have a domain, a server, or a GitHub account until you ask.

This skill covers the app in `apps/web/` (a static, config-driven signup page that POSTs one
urlencoded payload to a configurable `signupEndpoint` — see `AGENTS.md` §3). Any host that can serve
static files works; the only real choice is **where signups go**.

## Shortcut: there's a turnkey installer
The repo ships **`./install.sh`** — a dependency-light (bash + curl) interactive installer that does
Steps 0–2 below without an LLM: it collects the team's details, writes `apps/web/config.js`, presents
the same hosting menu, runs the chosen path, and prints next steps. **For most coaches, the fastest
help you can give is to run it *with* them and narrate:**

```bash
./install.sh            # interactive
./install.sh --help     # all flags (non-interactive / power-user mode)
```

Use it when the coach just wants to get live. Fall through to the hand-walked runbooks below when they
want to understand each step, are on a path the installer only scaffolds (DigitalOcean / their own
Traefik), or hit something the installer couldn't finish. Everything in this skill still applies —
the installer is a convenience layer over the same paths, config, and adapter contract.

## Step 0 — Configure the team first (all paths)
Before deploying anything, they must fill in their team's details. Walk them through copying
`apps/web/config.example.js` → `apps/web/config.js` and editing it. **Full field-by-field guide:
`references/configure.md`.** Do not skip this — a deploy with the placeholder config is not usable.

Do NOT commit `apps/web/config.js` (it's per-deployment, git-ignored like `.env`). The committed
`config.example.js` stays pristine.

## Step 1 — Triage: which path?
Ask these three questions, then pick from the table. Recommend, don't lecture.

1. **Do you want to own the signup data yourself, or is a spreadsheet / email inbox fine?**
2. **Do you have (or want) your own domain name?**
3. **Do you have a machine that's always on at home (Raspberry Pi, NAS, old laptop), or do you want it in the cloud?**

| If they… | Path | Why |
| --- | --- | --- |
| want the easiest thing, no server, data-in-a-form-inbox/Sheet is fine | **Static + form service** | Zero backend. Live in ~15 min. `references/static-form-service.md` |
| want to own their data + have an always-on box (or a Cloudflare Tunnel) | **Docker Compose** | One `docker compose up`, auto-HTTPS, data stays on their box. `references/docker-compose.md` |
| want cloud, no server to run, comfortable with a Vercel/GitHub login | **Vercel** | One-click-ish cloud host. Static works today; managed-DB backend is roadmap. `references/vercel.md` |

Default recommendation for a **non-technical** person with no server: **Static + form service (Formspree).**
Default for someone who said "I want to own the data" and has a box: **Docker Compose.**

## Step 2 — Follow the path's runbook
Open the matching `references/*.md` and follow it with them, one step at a time. Each ends with a
**test-signup checklist** — actually submit the form and confirm the signup arrived where it should.

## Step 3 — Go-live checklist (every path)
- [ ] Real test signup submitted → it arrived (inbox / Sheet / DB / webhook).
- [ ] The **honeypot** still blocks bots (leave the hidden "Website" field alone; it must never be filled by a human — don't remove it).
- [ ] Config shows **their** town, school, coach email, spots, cost — not the Clinton placeholder.
- [ ] Footer disclaimer is present: *"not sponsored by or affiliated with FIRST, the LEGO Group, or the school."*
- [ ] They know **where signup data lives** and **how to delete it** (see privacy note below).
- [ ] Flyer QR / printed URL points at the real deployed address.

## Guardrails (state these plainly to the coach)
- **Kids' data.** The form collects a child's first name + grade and a parent's contact info. That's
  the minimum to run a team — don't add more (no last names, DOB, addresses, photos). On the
  form-service path the data lives with that third party (Formspree/Google); on Compose it lives on
  their box; tell them which, and how to delete it later.
- **Trademark.** Keep the disclaimer and the ® marks. Don't let them add wording implying FIRST or the
  LEGO Group endorses the team.
- **Secrets.** Never paste API keys / webhook secrets into `config.js` if it will be committed — it's
  git-ignored for exactly this reason, but double-check before any `git add`.

## If they get stuck
Fall back to the simplest working thing: the site already has a **mailto fallback** — if no
`signupEndpoint` is set, a failed submit shows *"email the coach and we'll add you by hand."* A coach
with zero infrastructure can literally ship the page with no backend and still collect signups by
email. Offer that as the floor.
