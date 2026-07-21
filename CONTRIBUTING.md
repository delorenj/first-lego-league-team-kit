# Contributing — welcome, and thank you 🧱

First off: **thank you.** This kit exists so that a parent anywhere can start their
town's first FIRST® LEGO® League team without needing to be a developer. Every
improvement you make — a clearer sentence, a prettier flyer, one more deploy path —
helps real kids build robots. That's the whole point.

There's a place here for you whether or not you write code. Truly.

## You don't have to be a developer

Some of the most valuable help has nothing to do with programming:

- **Used the kit for your team?** Tell us what confused you, what broke, or what you
  wished existed. [Open an issue](../../issues) — "I'm a parent and X didn't make
  sense" is a *perfect* issue.
- **Better words.** The emails, the flyer copy, the website text — if you can say it
  warmer or clearer, we want it.
- **New deploy path.** Got a team running on some host we don't cover yet? Write down
  the steps and we'll turn it into an official runbook.
- **Translations, accessibility, screenshots, a kind README tweak** — all welcome.

Not sure where to start? Open an issue that just says hi and what you're hoping to do.
We'll help you find a first step.

## If you do want to touch the code

The project is a small, dependency-light static site plus deploy tooling. No build
step, no framework.

```bash
git clone https://github.com/delorenj/first-lego-league-team-kit.git
cd first-lego-league-team-kit
cp apps/web/config.example.js apps/web/config.js   # your town's details (git-ignored)
# open apps/web/index.html in a browser, or:
cd deploy/compose && cp .env.example .env && docker compose up -d
```

Read [`AGENTS.md`](AGENTS.md) — it's the project charter (architecture, the design
system, the roadmap). A few things there are **load-bearing**; please keep them intact:

- **The signup adapter contract.** The front end POSTs one fixed
  `application/x-www-form-urlencoded` payload (`parentName, parentEmail, parentPhone,
  childName, childGrade, notes, source`) to one configurable `signupEndpoint`. New
  fields → add them to the payload *and* document them for every deploy path.
- **Config-driven, not hard-coded.** Team-specific text/URLs/emails live in
  `apps/web/config.js` (git-ignored) and `config.example.js` (the neutral template).
  The shipped defaults must stay generic — never bake in a real town, email, or URL.
- **Kids' privacy.** The form collects a child's *first name* and grade only, plus a
  parent's contact. Never add a child's last name, birthday, address, or photo.
- **Trademark hygiene.** Keep the "not sponsored by / affiliated with FIRST, the LEGO
  Group, or the school" disclaimer and the ® marks. Use ® on first mention.
- **The bot honeypot and inline validation** in the form are doing real work — don't
  remove them.
- **Accessibility & motion.** Keep AA contrast, real `<label>`s, and gate every
  decorative/looping animation behind `prefers-reduced-motion: reduce`.

## Sending a change

1. Fork, branch (`git checkout -b clearer-flyer-copy`).
2. Make your change. If it touches the signup site, load the page and actually try a
   submission — don't just eyeball it.
3. Open a pull request describing *what* and *why*. Screenshots are gold for anything
   visual.
4. Be kind in review, expect kindness back. See [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md).

No contribution is too small, and it's completely fine to open a draft PR and ask for
help finishing it.

## Licensing

By contributing, you agree your contributions are licensed under the project's
[Apache License 2.0](LICENSE). You keep the credit; everyone gets to use it.

Thanks for helping more kids get to the table. 🤖🧱
