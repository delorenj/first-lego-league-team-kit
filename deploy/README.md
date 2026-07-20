# Deploy

Getting the signup site online. **If you have an LLM assistant, just ask it to run the
`deploy-team-site` skill** — it triages the best path for you and walks it step by step.

Three paths (easiest → most control):

| Path | Owns data? | Needs | Folder / runbook |
| --- | --- | --- | --- |
| **Static + form service** | with Formspree/Google | a static host (free) | `.claude/skills/deploy-team-site/references/static-form-service.md` |
| **Docker Compose** | ✅ your box | Docker + a domain/tunnel | [`compose/`](compose/) · `…/references/docker-compose.md` |
| **Vercel** | cloud DB (roadmap) | a Vercel login | [`vercel/`](vercel/) · `…/references/vercel.md` |

Before any path: configure your team — `cp apps/web/config.example.js apps/web/config.js` and edit
(`.claude/skills/deploy-team-site/references/configure.md`).

Quick self-host:
```bash
cd deploy/compose && cp .env.example .env   # set SITE_DOMAIN
docker compose up -d
```
