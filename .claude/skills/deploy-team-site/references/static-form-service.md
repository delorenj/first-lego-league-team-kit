# Path A — Static site + form service (no backend, easiest)

**Best for:** a non-technical coach with no server. Live in ~15 minutes. Signups land in your email
(Formspree) or a Google Sheet (Apps Script). ~Free at team scale.

You host the static files anywhere, and point `signupEndpoint` at a service that receives the form.

## 1. Pick where signups go

### Option 1 (recommended): Formspree — signups → your email
Works with the site as-is (returns proper CORS + JSON; leave `optimisticSubmit: false`).
1. Sign up at **formspree.io**, create a new form, name it e.g. "LEGO League Signups".
2. Copy its endpoint — looks like `https://formspree.io/f/abcdxyz`.
3. In `apps/web/config.js`: `signupEndpoint: "https://formspree.io/f/abcdxyz"`.
4. First real submit triggers a one-time confirm email from Formspree — click it. Done. Getform.io and Basin work identically.

### Option 2: Google Apps Script — signups → your own Google Sheet (own the data, free)
1. Create a Google Sheet. Extensions → **Apps Script**. Paste:
   ```js
   function doPost(e) {
     var ss = SpreadsheetApp.getActiveSpreadsheet();
     var sh = ss.getSheetByName('Signups') || ss.insertSheet('Signups');
     if (sh.getLastRow() === 0) sh.appendRow(['when','parent','email','phone','child','grade','can help','notes','source']);
     var p = e.parameter;
     sh.appendRow([new Date(), p.parentName, p.parentEmail, p.parentPhone, p.childName, p.childGrade, p.helpWith, p.notes, p.source]);
     return ContentService.createTextOutput(JSON.stringify({ ok: true })).setMimeType(ContentService.MimeType.JSON);
   }
   ```
2. Deploy → **New deployment** → type **Web app** → execute as **you**, access **Anyone** → copy the `/exec` URL.
3. In `config.js`: `signupEndpoint: "<that /exec URL>"` **and** `optimisticSubmit: true` (Apps Script can't send CORS headers, so the page assumes success after posting).
4. In the Sheet, add Tools → Notification settings to email yourself on new rows if you want alerts.

## 2. Host the static files
The whole site is `apps/web/` (`index.html` + your `config.js`). Any static host works:

- **Cloudflare Pages / Netlify:** "Deploy" → connect the repo (or drag-drop the `apps/web` folder) → set the output/publish directory to `apps/web`. You get a free `*.pages.dev` / `*.netlify.app` URL and free HTTPS. Add a custom domain later in their dashboard.
- **GitHub Pages:** push the repo, Settings → Pages → serve from `/apps/web` (or move those two files to the Pages root). Free `*.github.io` URL.

> Drag-drop note: if you deploy by uploading the folder, make sure your edited `config.js` is in it
> (it's git-ignored, so a repo-connected deploy needs it committed on a private branch OR set via the
> host — simplest is drag-drop of the folder that includes your `config.js`).

## 3. Test (do this before printing flyers)
- [ ] Open the deployed URL on your **phone** (every real visitor arrives via the flyer QR).
- [ ] Submit a real test signup.
- [ ] Confirm it arrived (Formspree email / the Sheet row).
- [ ] Delete the test row/email.
- [ ] Update the flyer QR + printed URL to this address.

## Data & privacy
Signups live with **Formspree/Google**, not you-you. Fine for a team roster, but know it's there and
delete signups when the season ends. If you'd rather keep data on your own box, use **Path B (Compose)**.
