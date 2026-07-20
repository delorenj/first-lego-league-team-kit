# services/api — self-host signup backend

**Status: roadmap (v0.1).** The reference **signup adapter** for the Docker Compose path, so a coach
owns their data end-to-end without a third-party form service.

## Contract it implements (`AGENTS.md` §3)
```
POST /api/signup   (application/x-www-form-urlencoded)
  parentName, parentEmail, parentPhone, childName, childGrade, notes, source
  → validate + honeypot-safe → insert into SQLite → notify coach (email/webhook) → 200 JSON { ok: true }

GET  /api/roster   (auth required)
  → the coach's signup list (for the roster/admin view, v0.2)
```

## Design intent
- **SQLite file** on a mounted volume — the coach's data, portable, backup-able.
- **Tiny + boring**: one small service (Bun/Node or Go), no framework sprawl. Must return proper CORS headers so the front end keeps `optimisticSubmit: false`.
- **Minimize kids' data** (`AGENTS.md` §8): store only the contract fields; provide a delete path.
- Wired into `deploy/compose/docker-compose.yml` as a second service behind Caddy; front end sets `signupEndpoint: "/api/signup"`.

Build this after the BMAD PRD defines acceptance criteria. Drive it through the `master-builder` agent.
