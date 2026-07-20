// ── LEGO League Team Kit — team configuration ───────────────────────────────
// Copy this file to `config.js` and fill in YOUR team's details:
//     cp config.example.js config.js
// `config.js` is git-ignored (per-deployment, like .env). It holds only public info
// (your coach email shows on the page) — never put secrets or API keys here.
// Field-by-field guide: .claude/skills/deploy-team-site/references/configure.md

window.TEAM_CONFIG = {
  // Where signups go — set by your deploy path (a Formspree URL, your own API, an n8n webhook…).
  // Empty string ("") = the page falls back to an "email the coach" message only.
  signupEndpoint: "",

  // Set true ONLY for endpoints that can't return CORS headers (e.g. a Google Apps Script Web App).
  // Leave false for Formspree, your own API, or n8n.
  optimisticSubmit: false,

  // Optional: your public site URL, used only for the og:url social-share tag. Leave "" to omit it.
  siteUrl: "",

  // ── Your team ──────────────────────────────────────────────────────────────
  townOrTeam:   "Your Town",          // fills "___'s first … team"
  region:       "Your Town, ST",      // small line under the studs
  seasonLabel:  "Fall 2026",          // short season tag (kicker)
  seasonName:   "2026–27 BIOGLOW",    // official season name (footer)
  coachName:    "Coach",              // your first name (optional)
  coachEmail:   "coach@example.com",  // questions + mailto fallback — shown publicly
  spots:        8,                    // roster size — "Only N spots"
  costPerChild: "$125",               // per-child cost, your currency string
  schoolName:   "your school",        // full school name (footer/disclaimer)

  // Optional: override the four LEGO brick colors. Delete this line to keep the classic palette.
  // colors: { red: "#D01012", yellow: "#F6BE00", blue: "#0057A6", green: "#00873E" },
};
