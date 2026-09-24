# Path B — Docker Compose (self-host, owns its data)

**Best for:** a coach who wants signup data on **their own machine** and has something always-on (a
Raspberry Pi, NAS, home server, or an old laptop) — or a cheap VPS. One command, automatic HTTPS.

The stack (`deploy/compose/`) is **Caddy** serving `apps/web/` with an auto-provisioned TLS cert.
Today it hosts the static site; point `signupEndpoint` at a form service or webhook (or, when the
`services/api` container lands, at the built-in `/api/signup` — see `AGENTS.md` roadmap).

## Prerequisites
- Docker + Docker Compose installed (`docker --version`, `docker compose version`).
- You've configured `apps/web/config.js` (see `configure.md`).

## 1. Set the domain
```bash
cd deploy/compose
cp .env.example .env
$EDITOR .env         # set SITE_DOMAIN
```
- **Just testing locally?** Leave `SITE_DOMAIN=localhost`. Caddy serves `https://localhost` with a local cert.
- **Going public?** Set `SITE_DOMAIN=lego.yourdomain.org` and make sure that name resolves to this box (see step 3).

## 2. Start it
```bash
docker compose up -d
docker compose logs -f caddy      # watch it obtain a certificate; Ctrl-C to stop watching
```
Visit `https://localhost` (or your domain). You should see the signup page with your config.
Edit `config.js` anytime and just reload — no rebuild.

## 3. Make it reachable from the internet (pick one)
Caddy needs ports **80 and 443** reachable at `SITE_DOMAIN` to get a real HTTPS cert.
- **Static IP / port-forward:** point an A record at your public IP; forward 80+443 to this box.
- **No static IP / behind CGNAT (common at home): Cloudflare Tunnel.** Run `cloudflared` pointing a
  hostname (e.g. `lego.yourdomain.org`) at `http://localhost:80`; DNS + HTTPS handled by Cloudflare,
  no ports to open. (If you use a Tunnel, you can even set `SITE_DOMAIN=localhost` and let the tunnel
  terminate TLS.)

## 4. Test
- [ ] Load the site over **HTTPS** on your phone (off wifi, on cellular, to prove it's public).
- [ ] Submit a real test signup → confirm it reached your `signupEndpoint`.
- [ ] `docker compose ps` shows the service `Up`; `docker compose restart` survives a reboot (`restart: unless-stopped` is set).
- [ ] Point the flyer QR at your domain.

## Data & privacy
Static files + certs live in the `caddy_data` volume on your box. When the signup API adapter is
added, signups go to a SQLite file you control — **you own the roster.** Back up the volume; delete
signup data at season end.

## Common issues
- **Cert won't issue:** DNS not pointing here yet, or 80/443 not reachable. Use `localhost` or a Cloudflare Tunnel while you sort DNS.
- **Page shows "Your Town":** `config.js` wasn't created/edited, or isn't in `apps/web/`. It's mounted read-only into the container — re-check the file, then reload.
- **Port 80 in use:** another web server/Traefik is bound. Stop it, or put Caddy behind your existing reverse proxy instead of publishing 80/443 here.
