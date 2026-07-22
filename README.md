# 🧱 FIRST LEGO League Team Kit

**A free, open-source kit for starting a FIRST® LEGO® League team at your school —
and actually filling the roster.**

[![License: Apache 2.0](https://img.shields.io/badge/license-Apache_2.0-blue.svg)](LICENSE)
&nbsp;•&nbsp; Made by a volunteer dad, given away so any parent can do the same.
&nbsp;•&nbsp; **[Homepage + live demo →](https://delorenj.github.io/first-lego-league-team-kit/)**

You get a stylish mobile **signup site**, a print **flyer**, ready-to-send **outreach
emails**, and a few **one-afternoon deploy paths** — self-host it, put it in the cloud,
or run it with no server at all. Edit **one file** with your town's details, pick how
you want to host it, and you're live. No account on anyone's service, no monthly fee,
no lock-in. It's yours.

> **Why this exists.** I'm a kindergarten dad who set out to start Clinton, NJ's first
> K–2 team and needed to find 8 kids. I built this to do it — then realized every town
> needs the same thing. So here it is, free, for you. Fill your roster. Have fun. 🤖

---

## What's in the box

- **Signup site** (`apps/web/`) — a mobile-first "BUILD. CODE. PLAY." page with a
  playful animated LEGO-brick vibe, honeypot spam protection, inline validation, and a
  graceful email fallback. Everything town-specific comes from one config file.
- **Print flyer** (`recruiting/flyer/`) — an 8.5×11 you can hand out at back-to-school
  night, with a QR code to your signup page.
- **Outreach emails** (`recruiting/emails/`) — a school/HSA pitch and a co-coach invite,
  fill-in-the-blanks.
- **Deploy paths** (`deploy/`, `services/api/`) — zero-backend static + a form service
  that emails you signups; self-host with Docker Compose (auto-HTTPS), optionally with a
  **built-in signup backend so you own your data**; or one-click to **DigitalOcean**
  (a Droplet *or* free App Platform static hosting). The installer drives all of them.

## Make it yours (quickstart)

**The one-command way — just run the installer** 🧱

```bash
git clone https://github.com/delorenj/first-lego-league-team-kit.git
cd first-lego-league-team-kit
./install.sh          # answer a few questions → it writes your config AND puts the site online
```

`install.sh` needs nothing but bash + curl (Docker only if you pick the self-host path). It asks you
a handful of plain questions — all about *you, the coach* (town, school, your email, spots, cost) —
writes `apps/web/config.js`, then walks you through hosting: **email me the signups** (no server),
**self-host with Docker**, **DigitalOcean**, or **your own reverse proxy**. Press **Enter** to take
the smart default anywhere. Full guide: **[docs/INSTALL.md](docs/INSTALL.md)**.

<details>
<summary>Prefer to do it by hand?</summary>

```bash
# 1. Your team, in one file
cp apps/web/config.example.js apps/web/config.js   # edit: town, school, coach email, spots, cost…

# 2. Get it online — easiest self-host (needs Docker):
cd deploy/compose && cp .env.example .env          # set your domain, or leave "localhost" to test
docker compose up -d                               # → your site, with automatic HTTPS

# 3. Point the flyer's QR at your live URL, print it, and go recruit. 🧱
```
</details>

**Not a techie? That's the whole point.** Run **`./install.sh`** above — it's built for exactly
this. Or, if you'd rather be walked through it conversationally, ask any AI assistant (Claude,
ChatGPT, …) to *"run the deploy-team-site skill in this repo"* and it'll ask you the same couple of
plain questions — *Do you want to own the data? Do you have a domain? Want it free?* — and can run
the installer for you, then test a real signup together.

| Deploy path | Owns your data? | Good for |
| --- | --- | --- |
| **Static + form service** | via Formspree / Google | no server, fastest, free |
| **Docker Compose** | ✅ your own box | a Pi / NAS / cheap VPS |
| **Docker Compose + built-in backend** | ✅ your box (SQLite + private roster) | own your data, no third party |
| **DigitalOcean — Droplet** | ✅ your droplet | one-click cloud server, owns its data |
| **DigitalOcean — App Platform** | managed (static) | free cloud hosting, no server to run |
| **Your own Traefik + tunnel** | ✅ your box | you already run a reverse proxy |
| Vercel | managed | *(roadmap)* |

The **[installer](docs/INSTALL.md)** does every ✅/one-click path for you; the DigitalOcean paths use
DigitalOcean's `doctl` CLI. Full guides live in `.claude/skills/deploy-team-site/` and
[`docs/deploy/`](docs/deploy/).

## A note on kids & trademarks (please keep these)

- **Privacy first.** The form asks for a child's *first name* and grade only, plus a
  parent's contact — the minimum to reach a family. Please keep it that way, tell
  parents where signups go, and delete them at season's end.
- **Trademarks.** Every page ships the disclaimer *"not sponsored by or affiliated with
  FIRST, the LEGO Group, or the school"* and the ® marks. FIRST® and LEGO® belong to
  their owners; this is a volunteer community project. Leave those in.

## Want to help? 💛

This is a charity effort and contributions of *every* kind are welcome — including from
people who don't write code. Better words, a nicer flyer, one more deploy path, or just
telling us what confused you when you tried it. Start with
**[CONTRIBUTING.md](CONTRIBUTING.md)** (and be kind — see
[CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)). Building on it? `AGENTS.md` is the full charter.

## License

[Apache License 2.0](LICENSE) — take it, change it, deploy it, share it. Just keep the
notice. Go find your eight kids. 🧱🤖
