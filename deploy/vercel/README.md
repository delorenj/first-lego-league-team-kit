# Vercel deploy — variant

**Status: roadmap.** Static hosting on Vercel works today (point the project's root at `apps/web` and
pair it with a Path A `signupEndpoint`). This folder will hold the Vercel-native backend so signups
store in a managed cloud DB (Vercel Postgres/KV or Turso) with a roster view — no third-party form
service.

Planned contents:
- `vercel.json` — routes + static build of `apps/web`
- `api/signup.*` — serverless function implementing the **signup-adapter contract** (`AGENTS.md` §3): accepts the urlencoded payload, writes the DB, notifies the coach.
- `api/roster.*` — authed roster read.

Until it lands, follow `.claude/skills/deploy-team-site/references/vercel.md` (static + form service behind Vercel hosting).
