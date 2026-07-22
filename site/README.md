# site/ — the project homepage

The public homepage for the kit itself (not a team's signup site — that's `apps/web/`).
Deployed to **GitHub Pages** by `.github/workflows/pages.yml`, which assembles:

```
/            ← site/index.html (+ og.png)     the homepage
/demo/       ← apps/web/                      the live demo signup page
```

The demo has no `config.js` (it's git-ignored), so it renders the kit's neutral
defaults — exactly what a fresh clone looks like. Live at:
**https://delorenj.github.io/first-lego-league-team-kit/**

First deploy: the workflow runs `actions/configure-pages@v5` with `enablement: true`,
so it enables GitHub Pages on the repo by itself — no manual Settings step needed.

## Conventions

- Same rules as `apps/web/`: one self-contained HTML file, pure CSS/SVG animation,
  no libraries, no build step, everything decorative gated behind
  `prefers-reduced-motion: reduce`, AA contrast, 320px-safe.
- The design system is the signup site's neo-brutalist LEGO brick language
  (`AGENTS.md` §5) — the homepage is its big sibling, not a new brand.
- `og.png` is the 1200×630 social-share card referenced by the `og:image` meta tag.

## Preview locally

The demo iframe needs the Pages layout, so assemble it — one command, from anywhere
in the repo:

```bash
mise run site:preview        # assembles + serves → http://localhost:8419/
```

(`mise run site:build` just assembles, into `$TMPDIR/legofirst-site`.) Doing it by
hand instead? Run the same steps **from the repo root**:

```bash
mkdir -p /tmp/_site/demo
cp -r site/. /tmp/_site/
cp -r apps/web/. /tmp/_site/demo/ && rm -f /tmp/_site/demo/config.js
python3 -m http.server 8419 -d /tmp/_site   # → http://localhost:8419/
```
