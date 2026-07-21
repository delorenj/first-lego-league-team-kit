# Install the kit with `./install.sh`

The fastest way to go from "I cloned this" to "my signup site is live" — no LLM, no coding.
`install.sh` asks you a few plain questions, writes your team config, and deploys the site.

## Run it

```bash
# From a clone:
git clone https://github.com/delorenj/first-lego-league-team-kit.git
cd first-lego-league-team-kit
./install.sh

# Or straight from the internet (it offers to clone the repo for you first):
curl -fsSL https://raw.githubusercontent.com/delorenj/first-lego-league-team-kit/main/install.sh | bash
```

Press **Enter** to accept the smart default at any prompt. Everything it asks about is **you, the
coach** (town, school, your email, spots, cost) — it never collects a child's information.

## What it needs

- **bash + coreutils + curl** — on any Mac or Linux box already. That's it for the easy path.
- **Docker** — only if you choose the self-host path (it checks, and helps you install it / offers
  the no-server path instead).

No Node, no Python, no `npm install`, no build step.

## The hosting choices

| # | Choice | Owns data? | Needs | Status |
| --- | --- | --- | --- | --- |
| 1 | **Email me the signups** (Formspree / Google Apps Script) | with Google | nothing (a free static host) | ✅ full |
| 2 | **Self-host with Docker Compose** (Caddy auto-HTTPS) | ✅ your box | Docker + a domain | ✅ full |
| 3 | **DigitalOcean** (App Platform or Droplet) | cloud / your droplet | a DO login | 📋 guided runbook |
| 4 | **Your own Traefik proxy + tunnel** (parameterized) | ✅ your box | existing Traefik | 📋 guided runbook + template |

Choices 1 and 2 finish end-to-end inside the installer. Choices 3 and 4 write your config, generate
what they can, validate it, and hand you a short manual runbook (full auto-deploy is on the roadmap).

## Not interactive? (power users, CI, testing)

Everything is drivable by flags or env vars, so it's scriptable and testable:

```bash
# Email path, fully specified, nothing prompted:
./install.sh --yes --path email \
  --town "Maplewood" --school "Tuscan Elementary" --coach-email "you@example.com" \
  --spots 10 --cost '$150' --endpoint "https://formspree.io/f/abcdxyz"

# Self-host, validate the Compose config without bringing anything up:
./install.sh --yes --path compose --domain signup.mytown.org --dry-run

# See every flag:
./install.sh --help
```

Handy flags:

- `--dry-run` — prepare + validate everything, but **don't** run the live action (no `docker compose
  up`, no browser). Great for a safe trial.
- `--config-out <file>` — write `config.js` somewhere other than `apps/web/config.js` (used by tests
  so a live config is never clobbered).
- `--compose-env <file>` — write the Compose `.env` somewhere other than `deploy/compose/.env`.
- `--form-service formspree|google` — pick the email-path catcher without prompting. `google`
  (Apps Script) automatically sets `optimisticSubmit: true`, which that host requires.

## Re-running

`install.sh` is safe to run again. If a `config.js` already exists it's backed up (timestamped)
before the new one is written, so you never lose your previous settings.

## Prefer an assistant?

If you'd rather be walked through it conversationally, ask any AI assistant to **"run the
deploy-team-site skill in this repo."** It triages the same choices and can just run this installer
for you.
