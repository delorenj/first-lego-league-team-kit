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
  // Roster size — "Only N spots". Know the real cap before you promise it: for 2026–27 a
  // traditional FLL Explore team is 2 adult coaches + 2–6 kids, and Challenge is up to 10.
  // A Class Pack holds up to 24 but costs $2,900/season vs $500 and can't attend an official
  // festival. Setting this ABOVE the cap on purpose is a legitimate strategy — extra signups
  // become a second team and, more importantly, a bigger pool to find your co-coach in (see
  // helpOptions below) — but say so in spotsLine so no family thinks they're guaranteed a seat.
  spots:        8,
  costPerChild: "$125",               // per-child cost, your currency string
  schoolName:   "your school",        // full school name (footer/disclaimer)

  // ── Which FIRST LEGO League division? (drives the grade/age copy + the grade buttons) ─────────
  // 2026–27 BIOGLOW runs TWO editions in parallel, and picking a kit means picking an edition:
  //   • Founders Edition (the classic path) — Explore, Grades 2–4 / ages 6–10, on LEGO® Education
  //     SPIKE™ Essential; and Challenge, Grades 4–8, on SPIKE Prime.
  //   • Future Edition (the new path) — Grades K–2 (ages 5–7) and 3–8, on LEGO® Education Computer
  //     Science & AI kits. Note there is NO Explore division in Future Edition.
  // Set these to match your choice — OR keep it wide to gauge interest first, then form the right
  // team(s) from who signs up. (This is the last FLL season either way; see AGENTS.md §3.)
  gradeBand:    "Grades K–2",         // the "Who" line + share text
  ageRange:     "ages 5–7",           // shown next to the grade band
  audience:     "kindergartners",     // hero: "…League team for {audience}"
  programName:  "FIRST LEGO League K–2",   // the "What" chip, bolded
  programKit:   "LEGO® Education kits",     // the kit the program uses
  // The signup form's grade buttons — list ANY number (they wrap). A single grade to lock a team,
  // or a wide range (e.g. ["K","1st","2nd","3rd","4th","5th"]) to measure demand before you commit.
  grades:       ["K", "1st", "2nd"],

  // The line above the form. Leave unset to use the default "Only {spots} spots… first come, first built"
  // (good for selling one team). Override for a demand-gauging, all-grades-welcome tone, e.g.:
  //   spotsLine: "Spots are limited — sign up to save your child's place. We're forming teams by grade this fall.",

  // ── "Can you help?" — turn your signups into your volunteer bench ──────────────────────────
  // This is not optional politeness — it is a registration blocker. FIRST requires TWO
  // background-screened lead coaches for the whole season, and as of 2026–27 you cannot even
  // open your youth roster until both have cleared Youth Protection. So you need a second name
  // before you need anything else, and your co-coach is almost always already in your own signup
  // pool: asking HERE — right after a parent has committed their child — converts far better than
  // asking cold, months earlier. List ANY number of options (they stack); each is a checkbox, and
  // the ticked ones ride along in the signup as `helpWith` (semicolon-separated).
  // Set to [] to hide the whole block.
  helpOptions: [
    "Be a co-coach with me",
    "Be a second adult in the room some weeks",
    "Help with snacks & logistics",
    "Help find a place to meet",
    "Just the big expo day",
  ],
  // Optional: override the line under "Can you help?" — keep it low-pressure and specific.
  //   helpPrompt: "Totally optional. Even one 'yes' makes the season happen.",

  // Optional: override the four LEGO brick colors. Delete this line to keep the classic palette.
  // colors: { red: "#D01012", yellow: "#F6BE00", blue: "#0057A6", green: "#00873E" },
};
