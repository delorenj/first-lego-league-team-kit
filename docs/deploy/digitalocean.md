# Path C — DigitalOcean (cloud)

**Best for:** a coach who wants it in the cloud (no home box to keep online). The fastest route is the
**one-click Droplet** the installer provisions for you; two good manual options are below if you'd
rather click through a dashboard.

## Option 0 — One-click Droplet (recommended, fully automated)
If you have DigitalOcean's [`doctl`](https://docs.digitalocean.com/reference/doctl/how-to/install/)
CLI installed and authenticated, the installer does the *whole thing* — no dashboard, no SSH:

```bash
doctl auth init                       # one-time: paste a DO API token
./install.sh --path digitalocean      # answer a couple of questions, confirm, done
```

What it does: creates a cheap Droplet (default `s-1vcpu-1gb`, ~$6/mo) whose **cloud-init** installs
Docker, clones the kit, drops in **your** `config.js`, and runs the same Caddy auto-HTTPS stack as the
Docker Compose path. So the Droplet **owns its data** and gets a real Let's Encrypt certificate on its
own. The installer then prints the Droplet's IP and either:

- **auto-creates the DNS `A` record** if your domain is managed on DigitalOcean, or
- tells you the exact `A` record to add at your registrar.

Give the first boot ~2–3 minutes (cloud-init installs Docker), then your site is live at
`https://your-domain` once DNS resolves.

**Own your data (recommended on a Droplet):** the installer offers a built-in signup backend —
`services/api`, a tiny SQLite service behind Caddy. Choose it and every signup is stored on *your*
Droplet (no third-party form service), with a private roster at `https://your-domain/api/roster`. The
installer generates a roster password and prints it. See [`services/api`](../../services/api/README.md).

Useful flags (see `./install.sh --help`): `--domain`, `--backend`/`--no-backend`,
`--roster-user`/`--roster-pass`, `--do-region`, `--do-size`, `--do-image`, `--do-name`, and
`--do-provision` (to create the Droplet in non-interactive/CI runs). It's billable, so the installer
always **confirms before creating**, and reminds you how to destroy it (`doctl compute droplet delete <name>`).

## Option 0b — One-click App Platform (automated, static site)
Prefer no server at all? App Platform hosts the static files free. If `doctl` is authenticated and your
site is in **your own GitHub repo** (with `config.js` committed — see the note in Option A), the
installer creates the app for you:

```bash
./install.sh --path digitalocean --do-app --do-repo your-user/first-lego-league-team-kit
```

It writes a DO app spec (`static_sites`, `source_dir: /apps/web`), runs `doctl apps create --spec … --wait`,
and prints the live `*.ondigitalocean.app` URL. **One-time prerequisite:** your GitHub account must be
connected to DigitalOcean (Apps → Create App → GitHub → authorize) — a 2-click OAuth `doctl` can't do
for you. If it isn't connected yet, the installer writes the spec and tells you the one manual step, then
you re-run. App Platform static sites can't run the built-in backend (no server), so signups go to a form
service or your webhook.

> Prefer clicking through a dashboard, or don't want `doctl`? The manual options below are each ~15
> minutes. (The installer falls back to these automatically when `doctl` isn't set up.)

## Option A — App Platform by hand (static site, easiest)
No server to manage; DigitalOcean builds and hosts the static files.

1. Push this repo to **your** GitHub account.
   - `config.js` is git-ignored. For a repo-connected deploy, commit your `config.js` on a **private**
     fork/branch, or use Option B. (It only contains public info — your coach email — but keep the
     repo private if you'd rather not publish it.)
2. In DigitalOcean → **Apps** → **Create App** → connect the repo.
3. Resource type: **Static Site**. Set the **source/output directory** to `apps/web`.
4. **Create Resources** → deploy. You get a free `*.ondigitalocean.app` URL with HTTPS.
5. Add a custom domain later under the app's **Settings → Domains**.

## Option B — Droplet + Docker Compose (own the box)
A tiny always-on Linux server that owns its data. This just runs the kit's Compose path in the cloud.

1. Create the cheapest **Ubuntu Droplet**. Note its public IP.
2. Point your domain's **A record** at that IP (DigitalOcean → Networking → Domains, or your registrar).
3. SSH in and install Docker:
   ```bash
   curl -fsSL https://get.docker.com | sh
   ```
4. Clone the kit and run the installer, choosing the **Docker Compose** path with your real domain:
   ```bash
   git clone https://github.com/delorenj/first-lego-league-team-kit.git
   cd first-lego-league-team-kit
   ./install.sh --path compose --domain signup.yourtown.org
   ```
   Caddy fetches a real Let's Encrypt certificate automatically (ports 80/443 are open on a Droplet).

## The `doctl` CLI
Installing DigitalOcean's [`doctl`](https://docs.digitalocean.com/reference/doctl/how-to/install/)
and running `doctl auth init` is what unlocks **Option 0** above — the installer uses it to create the
Droplet, attach your account's SSH keys, look up the size price, and (when your domain is on DO)
create the DNS record for you. Without it, the installer writes your `config.js` and hands you the
manual options here.

## Test (any option)
- [ ] Load the live URL on your **phone** over cellular.
- [ ] Submit a real test signup → confirm it reached your `signupEndpoint`.
- [ ] Delete the test signup.
- [ ] Point the flyer QR at the live URL.

## Data & privacy
On App Platform the static files sit with DigitalOcean; **signups go wherever your `signupEndpoint`
points** (a form service or your own webhook). On a Droplet with Compose, data + certs live on your
Droplet. Either way: tell parents where signups land, and delete them at season's end.
