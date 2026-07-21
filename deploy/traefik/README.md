# Path D — Your own Traefik reverse proxy (+ optional tunnel)

**Best for:** a coach (or a coach's techie friend) who *already* runs [Traefik](https://traefik.io/)
as a reverse proxy — often with a Cloudflare Tunnel so no home ports need opening. This path parks a
tiny `nginx:alpine` container serving `apps/web` onto your existing proxy network with the right
Traefik labels.

> This is the **parameterized, shippable** version of a common homelab pattern. It is **bring your
> own infrastructure**: you supply the domain, the network name, and the certresolver. The kit never
> ships anyone's personal domain or tunnel as a default (see `AGENTS.md` §8).

`./install.sh` → **"Your own reverse proxy"** writes the `.env` for you and validates the template.
The steps below are the same thing by hand.

## Prerequisites
- Traefik already running, attached to an **external** Docker network (commonly named `proxy`).
- Either a configured **certresolver** (Let's Encrypt) *or* a **Cloudflare Tunnel** terminating TLS
  in front of Traefik.
- A domain **you** control, with DNS (or a tunnel route) pointing the hostname at your Traefik.
- You've configured `apps/web/config.js` (the installer writes it for you; or copy
  `../../apps/web/config.example.js` → `apps/web/config.js` and edit).

## 1. Set your values
```bash
cd deploy/traefik
cp .env.example .env
$EDITOR .env          # SITE_DOMAIN, PROXY_NETWORK, CERT_RESOLVER
docker network ls     # confirm your external Traefik network name matches PROXY_NETWORK
```

## 2. Validate, then bring it up
```bash
docker compose --env-file .env config     # sanity-check the interpolated config
docker compose up -d
docker compose logs -f web
```
Because the container joins your **existing** Traefik network, Traefik discovers it by its labels and
starts routing `https://SITE_DOMAIN` to it. Edit `apps/web/config.js` anytime and reload — no rebuild.

## 3. Cloudflare Tunnel variant (no open ports)
If you front Traefik with a Cloudflare Tunnel, add a public-hostname route in the tunnel
(`SITE_DOMAIN` → your Traefik service) and let Cloudflare handle TLS. You can then drop the
`certresolver` label if the tunnel terminates HTTPS. Nothing in this file assumes a specific tunnel.

## 4. Test
- [ ] Load `https://SITE_DOMAIN` on your phone over cellular (proves it's public).
- [ ] Submit a real test signup → confirm it reached your `signupEndpoint`.
- [ ] `docker compose ps` shows the service `Up`.
- [ ] Point the flyer QR at your domain.

## Data & privacy
Static files live on your box; **where signups go is your `signupEndpoint`** (a form service, your
own webhook, or the future `services/api`). Tell parents where the data lives and delete it at
season's end.

## Notes
- **Auto-deploy status:** the installer *generates and validates* this template but does **not** run
  `docker compose up` for you here — it can't safely touch your live Traefik. Run step 2 yourself on
  the Traefik host.
- **Never commit `.env`** with a real domain you don't want public — it's git-ignored for that reason.
