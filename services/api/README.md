# services/api — self-host signup backend (own your data)

**Status: ✅ real.** The reference **own-your-data adapter** (`AGENTS.md` §3): run this next to the
static site and every signup lands in a **SQLite file on your own box** — no third-party form service,
no cloud database. It's the cloud/Compose path's "I want to own the data" answer.

**Zero third-party dependencies** — Python standard library only (`http.server`, `sqlite3`, `smtplib`).
Nothing to `pip install`, no build step, nothing extra to keep patched.

## Run it (one command)
```bash
cd services/api
cp .env.example .env          # set SITE_DOMAIN + a roster password (+ optional email)
docker compose up -d          # Caddy (auto-HTTPS) + the signup API, on one domain
```
Then point the site at it — in `apps/web/config.js`:
```js
signupEndpoint: "/api/signup",   // same origin as the page → no CORS, keep optimisticSubmit: false
```
(The installer does all of this for you: `./install.sh` → **Docker Compose** → "own the data".)

## What you get
| URL | What | Auth |
| --- | --- | --- |
| `POST /api/signup` | the adapter endpoint — validates, honeypot-drops bots, writes SQLite, optionally emails you | none (public form) |
| `GET /api/roster` | a private, on-brand HTML roster of every signup (newest first) with a **Delete** button | Basic auth |
| `GET /api/roster?format=csv` | the roster as a spreadsheet download | Basic auth |
| `GET /api/roster?format=json` | the roster as JSON | Basic auth |
| `GET /api/health` | liveness + signup count | none |

## Configure (environment / `.env`)
| Var | Default | Purpose |
| --- | --- | --- |
| `SITE_DOMAIN` | `localhost` | domain Caddy serves + gets HTTPS for |
| `ROSTER_USER`, `ROSTER_PASS` | — | set **both** to enable the roster (unset → roster returns 503) |
| `COACH_EMAIL` | — | where signup notification emails go |
| `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASS`, `SMTP_FROM`, `SMTP_TLS` | `587`/`1` | set `SMTP_HOST` (+ `COACH_EMAIL`) to turn on email notifications |
| `DB_PATH` | `/data/signups.db` | SQLite location (a mounted volume — back it up) |
| `PORT` | `8080` | listen port (behind Caddy) |

Email is best-effort: if SMTP isn't set or a send fails, the signup is **still saved** — you just won't
get the email. The roster always works with no external services.

## Your data
- It's **one SQLite file** in the `api_data` volume (`DB_PATH`). Back it up, copy it, grep it — it's yours.
- Export anytime: `GET /api/roster?format=csv`.
- Delete a row from the roster's **Delete** button, or wipe everything by removing the volume
  (`docker compose down -v`). Tell families where their data lives and delete it at season's end
  (`AGENTS.md` §8).

## Finding your co-coach
The signup carries a `helpWith` field — the **"Can you help?"** boxes a parent ticked. Parents who
offered are highlighted on the roster, counted in a `🙋 N offered to help` pill, and flagged in the
notification email's subject line, because that reply is worth sending the same day. Most new teams
find their second adult here rather than through a cold ask. Turn the options into whatever you
actually need via `helpOptions` in `apps/web/config.js`.

An older `signups.db` is migrated in place on boot — new contract columns are `ALTER TABLE`d in and
existing rows are left alone, so upgrading the kit never costs you your signups.

## Data minimization (guardrail)
Stores **only** the contract fields — a child's first name + grade, a parent's contact info, and what
that parent volunteered for. No last names, DOB, addresses, or photos. The roster is auth-gated and
marked `noindex`. Keep it that way.

## Test-signup checklist
- [ ] `curl -fsS https://SITE_DOMAIN/api/health` → `{"ok": true, ...}`
- [ ] Submit the real form once → success screen, and the row appears in `/api/roster`.
- [ ] The **honeypot** still works: a POST with a non-empty `website` field returns `{"ok":true}` but
      stores nothing (check the roster count doesn't change).
- [ ] Roster requires your password; CSV downloads; Delete removes a test row.
