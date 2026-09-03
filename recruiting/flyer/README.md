# Flyer

`lego-league-flyer.pdf` — print-ready 8.5×11 recruiting flyer in the kit's neo-brutalist LEGO style.
Who / What / When / Cost grid, two honesty panels (grade band + the co-coach ask), and a QR code.

## The PDF is generated. Do not hand-edit it.

```
./build.sh          # flyer.html -> lego-league-flyer.pdf  (headless Chrome)
```

- **`flyer.html` is the source of truth.** Edit it, then rebuild.
- Until Sept 2026 the PDF was a hand-made artifact with **no source file**, which is exactly how it
  drifted out of sync with the site: it was still advertising a K–2 band and *"coached by two
  volunteer CPS parents"* when there was one coach and one soft, unscreened offer. A flyer that
  contradicts reality is worse than no flyer — it's the artifact families actually act on.

## It reads your team config

`flyer.html` loads `apps/web/config.example.js` first, then `apps/web/config.js` (git-ignored, absent
in a fresh clone) on top — so the real config wins when it exists. Grade band, ages, school name,
coach name/email, season and site URL all come from there, which means **the flyer and the signup
site cannot disagree** about who the team is for.

Prose that can't be meaningfully templated (the honesty panels, the coach ask) lives inline in
`flyer.html`. Rewrite it for your own team — don't ship Clinton's wording.

## The QR code — read this before you print

`src/qr.js` embeds the QR as a base64 data URI so the flyer renders with no network and no build
step. **It encodes `lego.delo.sh` — Jarad's Clinton site.**

If you deploy anywhere else you **must** regenerate it for your own `signupUrl`. A flyer that scans
to someone else's signup page is worse than no flyer at all. Any QR generator works; re-encode as a
data URI and replace the value in `src/qr.js`:

```
python3 -c "import base64,sys;print('window.FLYER_QR_DATA_URI = \"data:image/png;base64,'+base64.b64encode(open(sys.argv[1],'rb').read()).decode()+'\";')" my-qr.png > src/qr.js
```

There is no QR *generator* in this repo on purpose — no dependency here can produce one, and a
silently malformed QR is a worse failure than a manual step, since the QR is the flyer's primary
call to action. Generating one from `config.signupUrl` automatically is still roadmap.

## What the copy is careful about

These are deliberate and worth preserving if you adapt the flyer:

- **No fixed seat count as scarcity.** "Only 8 spots" was false urgency with zero signups behind it,
  and it overstated what one Explore roster (about 2–6 kids) can hold.
- **No cost number.** FIRST charges **per team, not per child**. Verified 2026–27 Explore traditional
  is **$500** (registration + one SPIKE Essential set), excluding shipping *and* festival
  registration — so per-child cost swings roughly $83–$250 depending on roster size, and two teams
  means two registrations. Printing a number you can't honor on paper you can't correct is how a
  parent ends up angry in February. This is a real conversion cost, accepted knowingly.
- **The grade band is honest.** K–3 spans no single FIRST division, so the flyer says so outright
  rather than implying one roster.
- **The coach line is an ask, not a claim.** A team needs two screened adults; the flyer never
  pretends both exist, and it recruits the second one.
- **Where the data goes.** The form collects a child's first name and grade plus a parent's contact,
  so the flyer states it comes to the coach, not the school, and can be deleted on request (§8).
- **Trademark hygiene.** ® on first mention, plus the required non-affiliation line (§8).

See `AGENTS.md` §9 (roadmap) and drive larger changes through the `master-builder` agent.
