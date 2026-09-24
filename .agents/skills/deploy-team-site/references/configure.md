# Configure your team — `apps/web/config.js`

This is the **one file** a coach edits. It's plain JavaScript that sets `window.TEAM_CONFIG`; the
site reads it on load. Generic FIRST LEGO League copy is baked into the page — you only set what's
specific to *your* team.

## Do this first
```bash
cd apps/web
cp config.example.js config.js     # config.js is git-ignored — safe to put your details in it
$EDITOR config.js
```
If you skip this, the page falls back to neutral placeholders ("Your Town", `coach@example.com`) — a
clear sign it isn't configured yet.

## Fields

| Field | What it is | Example |
| --- | --- | --- |
| `signupEndpoint` | **Where signups go.** URL of your form service / webhook / API. Empty = mailto fallback only. Set by your deploy path. | `"https://formspree.io/f/abcdxyz"` |
| `optimisticSubmit` | Set `true` only if your endpoint can't return CORS headers (e.g. a Google Apps Script). Shows success without reading the response. Leave `false` for Formspree / your own API / n8n. | `false` |
| `townOrTeam` | Your town or team name — fills "___'s first … team". | `"Clinton"` |
| `region` | Small line under the studs. | `"Clinton, NJ"` |
| `seasonLabel` | Short season tag. | `"Fall 2026"` |
| `seasonName` | Official season name (footer). | `"2026–27 BIOGLOW"` |
| `coachName` | Coach first name (optional). | `"Jarad"` |
| `coachEmail` | Where questions go + the mailto fallback. Appears publicly on the page. | `"coach@example.com"` |
| `spots` | Roster size — "Only N spots". | `8` |
| `costPerChild` | Per-child cost, your currency string. | `"$125"` |
| `schoolName` | Full school name (footer/disclaimer). | `"Clinton Public School"` |
| `colors` | Optional brick-color overrides `{red,yellow,blue,green}`. Omit to keep the classic LEGO palette. | `{ red:"#D01012", … }` |
| `siteUrl` | Optional. Your deployed URL — used only for the social-share preview (`og:url`) when someone links your page. Leave `""` to omit it. | `"https://signup.yourtown.org"` |

## Notes
- **Kids' data:** the form asks for a child's *first name* and grade only — keep it that way.
- **Trademark:** the footer disclaimer and ® marks ship by default. Leave them in.
- `coachEmail` is shown publicly (that's the point — parents email you). Don't put anything private in `config.js`.
- After editing, just reload the page (static hosts) or re-run `docker compose up -d` (Compose) — no build step.
