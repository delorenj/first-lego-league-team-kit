# Path C — DigitalOcean (cloud)

**Best for:** a coach who wants it in the cloud (no home box to keep online) and is comfortable with
a GitHub + DigitalOcean login. Two good options; both are ~15 minutes.

> **Status:** the installer (`./install.sh` → **DigitalOcean**) writes your `config.js` and points
> you here. Fully-scripted auto-deploy (via `doctl`) is a roadmap item — the manual steps below are
> the supported path today, and they're quick.

## Option A — App Platform (static site, easiest)
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

## Optional: the `doctl` CLI
Installing DigitalOcean's [`doctl`](https://docs.digitalocean.com/reference/doctl/how-to/install/)
lets you script App Platform deploys (`doctl apps create --spec …`). A future installer version will
use it to automate Option A end-to-end.

## Test (either option)
- [ ] Load the live URL on your **phone** over cellular.
- [ ] Submit a real test signup → confirm it reached your `signupEndpoint`.
- [ ] Delete the test signup.
- [ ] Point the flyer QR at the live URL.

## Data & privacy
On App Platform the static files sit with DigitalOcean; **signups go wherever your `signupEndpoint`
points** (a form service or your own webhook). On a Droplet with Compose, data + certs live on your
Droplet. Either way: tell parents where signups land, and delete them at season's end.
