# Deploy

Getting the signup site online. **Easiest of all: run the installer — [`./install.sh`](../install.sh)
from the repo root** (`../docs/INSTALL.md`). It collects your team's details, writes your config, and
runs the path you pick. If you have an LLM assistant instead, ask it to run the **`deploy-team-site`
skill** — same paths, walked step by step (it can just run the installer for you).

Paths (easiest → most control):

| Path | Owns data? | Needs | Folder / runbook |
| --- | --- | --- | --- |
| **Static + form service** | with Formspree/Google | a static host (free) | `.claude/skills/deploy-team-site/references/static-form-service.md` |
| **Docker Compose** | ✅ your box | Docker + a domain/tunnel | [`compose/`](compose/) · `…/references/docker-compose.md` |
| **DigitalOcean** | cloud / your droplet | a DO login | [`../docs/deploy/digitalocean.md`](../docs/deploy/digitalocean.md) |
| **Your own Traefik + tunnel** | ✅ your box | existing Traefik | [`traefik/`](traefik/) · [`traefik/README.md`](traefik/README.md) |
| **Vercel** | cloud DB (roadmap) | a Vercel login | [`vercel/`](vercel/) · `…/references/vercel.md` |

Before any path: configure your team — `cp apps/web/config.example.js apps/web/config.js` and edit
(`.claude/skills/deploy-team-site/references/configure.md`).

Quick self-host:
```bash
cd deploy/compose && cp .env.example .env   # set SITE_DOMAIN
docker compose up -d
```
