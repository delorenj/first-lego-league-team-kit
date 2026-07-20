# Flyer

`lego-league-flyer.pdf` — print-ready 8.5×11 recruiting flyer in the kit's neo-brutalist LEGO style.
Who / What / When / Cost grid, "Scan to sign up in 30 seconds", and a QR code.

## Using it
- **The QR + printed URL point at `lego.delo.sh` — now LIVE (Clinton, Jarad's instance), so the Clinton
  flyer is ready to print.** For another team, the QR must be regenerated to *your* deployed site URL —
  a flyer that scans to someone else's page is worse than none.
- Print at home or at a copy shop; hand out at back-to-school night / drop-off / the library.

## Roadmap — flyer generator
A `config.js`-driven generator (same values as the site → a themed PDF with a QR encoding *your*
`signupUrl`) so each team gets a correct flyer with zero design work. Until then, treat this PDF as the
Clinton reference and regenerate the QR for your own URL (any QR tool → your deployed address).

See `AGENTS.md` §9 (roadmap) and drive the build through the `master-builder` agent.
