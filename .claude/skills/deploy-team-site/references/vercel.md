# Path C — Vercel (one-click cloud)

**Best for:** a coach who wants it in the cloud with nothing to self-host, and is OK creating a
Vercel + GitHub login. Free tier is plenty at team scale.

> **Status:** static hosting on Vercel works **today**. A Vercel-native backend (serverless function
> + managed database so signups store in the cloud without a third-party form service) is on the
> roadmap (`deploy/vercel/` stub, `AGENTS.md` §9). Until then, pair Vercel hosting with a
> `signupEndpoint` from **Path A** (Formspree / Apps Script).

## 1. Host the static site
1. Push this repo to your GitHub (keep `apps/web/config.js` out of public repos — put your config in a **private** repo, or use Path A's drag-drop).
2. On **vercel.com** → **Add New… → Project** → import the repo.
3. Framework preset: **Other**. **Root Directory: `apps/web`.** No build command; output is the folder itself.
4. Deploy → you get a `*.vercel.app` URL with automatic HTTPS. Add a custom domain in Project → Settings → Domains.

## 2. Point signups somewhere
Set `signupEndpoint` in `apps/web/config.js` to a Path A endpoint (Formspree recommended). Redeploy
(Vercel redeploys on push, or hit "Redeploy").

## 3. Test
- [ ] Open the `*.vercel.app` URL on your phone; submit a real test signup.
- [ ] Confirm it arrived at your form service.
- [ ] Custom domain (optional) resolves + serves HTTPS.
- [ ] Flyer QR points at the final URL.

## 4. When the native backend ships
You'll be able to deploy the serverless variant from `deploy/vercel/` and set a managed DB
(Vercel Postgres/KV or Turso) — signups store in the cloud, roster view included, no third-party form
service. Track it in `AGENTS.md` §9. Until then, Path A behind Vercel hosting is the supported combo.

## Data & privacy
With a form service, signup data lives with that provider; Vercel just serves the page. When the
managed-DB backend lands, data lives in your cloud database account. Either way: tell parents where it
goes, and delete it at season end.
