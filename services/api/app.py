#!/usr/bin/env python3
"""
services/api — the own-your-data signup backend for the FIRST(R) LEGO(R) League Team Kit.

The reference "own your data" adapter (AGENTS.md §3): a coach runs this next to the static site
(behind Caddy) and every signup lands in a SQLite file on their own box — no third-party form
service, no cloud database. Zero third-party dependencies: Python standard library only
(http.server, sqlite3, smtplib), so there's no `pip install`, no build step, nothing to keep patched.

Endpoints
  POST /api/signup            (application/x-www-form-urlencoded)
       parentName, parentEmail, parentPhone, childName, childGrade, notes, source
       -> validate + honeypot -> INSERT into SQLite -> (optional) email the coach -> 200 {"ok": true}
  GET  /api/roster            (HTTP Basic auth)            -> neo-brutalist HTML roster
  GET  /api/roster?format=json|csv   (auth)               -> machine-readable / spreadsheet export
  POST /api/roster/delete     (auth) id=<n>               -> delete one signup (privacy: prune a test/duplicate)
  GET  /api/health                                        -> {"ok": true}

Config via environment (all optional unless noted)
  DB_PATH=/data/signups.db        where the SQLite file lives (mount a volume here)
  PORT=8080                       listen port
  ROSTER_USER, ROSTER_PASS        set BOTH to enable the roster view (unset -> roster returns 503)
  COACH_EMAIL                     where signup notifications are sent
  SMTP_HOST, SMTP_PORT=587, SMTP_USER, SMTP_PASS, SMTP_FROM, SMTP_TLS=1
                                  set SMTP_HOST (+ COACH_EMAIL) to turn on email notifications
  MAX_BODY_BYTES=65536            reject oversized POST bodies

Guardrails (AGENTS.md §8): we store ONLY the contract fields — a child's first name + grade and a
parent's contact info. No last names, DOB, addresses, or photos. The roster is auth-gated and the
coach can delete any row. A failed email never fails a signup (the data is saved first).
"""

import base64
import csv
import hmac
import html
import io
import json
import os
import re
import smtplib
import sqlite3
import sys
from datetime import datetime, timezone
from email.message import EmailMessage
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

# ── Config (read once at boot) ──────────────────────────────────────────────────────────────────
DB_PATH        = os.environ.get("DB_PATH", "/data/signups.db")
PORT           = int(os.environ.get("PORT", "8080"))
ROSTER_USER    = os.environ.get("ROSTER_USER", "")
ROSTER_PASS    = os.environ.get("ROSTER_PASS", "")
COACH_EMAIL    = os.environ.get("COACH_EMAIL", "")
SMTP_HOST      = os.environ.get("SMTP_HOST", "")
SMTP_PORT      = int(os.environ.get("SMTP_PORT", "587"))
SMTP_USER      = os.environ.get("SMTP_USER", "")
SMTP_PASS      = os.environ.get("SMTP_PASS", "")
SMTP_FROM      = os.environ.get("SMTP_FROM", "") or (COACH_EMAIL or "lego-league@localhost")
SMTP_TLS       = os.environ.get("SMTP_TLS", "1") not in ("0", "false", "no", "")
MAX_BODY_BYTES = int(os.environ.get("MAX_BODY_BYTES", "65536"))

# The Signup Adapter Contract fields (AGENTS.md §3), in roster/CSV column order.
FIELDS = ["parentName", "parentEmail", "parentPhone", "childName", "childGrade", "notes", "source"]
EMAIL_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")


# ── Storage ─────────────────────────────────────────────────────────────────────────────────────
def db():
    """A fresh connection per request — simple and safe under the threading server."""
    os.makedirs(os.path.dirname(DB_PATH) or ".", exist_ok=True)
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def init_db():
    with db() as conn:
        conn.execute(
            """CREATE TABLE IF NOT EXISTS signups (
                 id           INTEGER PRIMARY KEY AUTOINCREMENT,
                 ts           TEXT NOT NULL,
                 parentName   TEXT,
                 parentEmail  TEXT,
                 parentPhone  TEXT,
                 childName    TEXT,
                 childGrade   TEXT,
                 notes        TEXT,
                 source       TEXT
               )"""
        )


def insert_signup(rec):
    with db() as conn:
        cur = conn.execute(
            "INSERT INTO signups (ts, parentName, parentEmail, parentPhone, childName, childGrade, notes, source)"
            " VALUES (?,?,?,?,?,?,?,?)",
            (datetime.now(timezone.utc).isoformat(timespec="seconds"),
             rec["parentName"], rec["parentEmail"], rec["parentPhone"],
             rec["childName"], rec["childGrade"], rec["notes"], rec["source"]),
        )
        return cur.lastrowid


def all_signups():
    with db() as conn:
        return [dict(r) for r in conn.execute("SELECT * FROM signups ORDER BY id DESC")]


def delete_signup(rid):
    with db() as conn:
        conn.execute("DELETE FROM signups WHERE id = ?", (rid,))


def count_signups():
    with db() as conn:
        return conn.execute("SELECT COUNT(*) AS n FROM signups").fetchone()["n"]


# ── Email notification (best effort; never blocks or fails a signup) ─────────────────────────────
def notify_coach(rec, rid):
    if not (SMTP_HOST and COACH_EMAIL):
        return  # email notifications not configured — the signup is already saved
    try:
        msg = EmailMessage()
        msg["Subject"] = f"🧱 New LEGO League signup: {rec['childName'] or 'a builder'} (grade {rec['childGrade']})"
        msg["From"] = SMTP_FROM
        msg["To"] = COACH_EMAIL
        if EMAIL_RE.match(rec["parentEmail"] or ""):
            msg["Reply-To"] = rec["parentEmail"]
        body = "A family just signed up for your team.\n\n" + "\n".join(
            f"  {k}: {rec[k]}" for k in FIELDS
        ) + f"\n\nSignup #{rid}. See the full roster at /api/roster.\n"
        msg.set_content(body)
        with smtplib.SMTP(SMTP_HOST, SMTP_PORT, timeout=10) as s:
            if SMTP_TLS:
                s.starttls()
            if SMTP_USER:
                s.login(SMTP_USER, SMTP_PASS)
            s.send_message(msg)
    except Exception as e:  # noqa: BLE001 — log and move on; the data is safe either way
        print(f"[notify] email to coach failed (signup #{rid} still saved): {e}", file=sys.stderr)


# ── Roster HTML (neo-brutalist LEGO brick, per AGENTS.md §5) ─────────────────────────────────────
ROSTER_CSS = """
:root{--red:#D01012;--yel:#F6BE00;--blu:#0057A6;--grn:#00873E;--ink:#1a1a2e;--muted:#55556b;--paper:#FFFDF7}
*{box-sizing:border-box}body{margin:0;padding:24px;background:var(--paper);color:var(--ink);
font-family:'Poppins',system-ui,-apple-system,Segoe UI,Roboto,sans-serif;max-width:1000px;margin:0 auto}
.studs{display:flex;gap:6px;margin-bottom:14px}.studs i{width:26px;height:26px;border:3px solid var(--ink);
border-radius:7px;box-shadow:3px 3px 0 var(--ink)}
h1{font-size:1.9rem;font-weight:800;letter-spacing:-.02em;margin:.2em 0}
.sub{color:var(--muted);margin:0 0 18px}
.bar{display:flex;gap:10px;flex-wrap:wrap;align-items:center;margin:0 0 18px}
.pill{border:3px solid var(--ink);border-radius:10px;padding:6px 12px;font-weight:700;background:#fff;
box-shadow:4px 4px 0 var(--ink);text-decoration:none;color:var(--ink);display:inline-block}
.pill.count{background:var(--yel)}.pill.csv{background:var(--grn);color:#fff}.pill.json{background:var(--blu);color:#fff}
table{width:100%;border-collapse:separate;border-spacing:0;border:3px solid var(--ink);border-radius:12px;
overflow:hidden;box-shadow:6px 6px 0 var(--ink);background:#fff}
th,td{padding:10px 12px;text-align:left;border-bottom:2px solid #ece9df;font-size:.94rem;vertical-align:top}
th{background:var(--ink);color:var(--paper);font-weight:700;letter-spacing:.01em}
tr:last-child td{border-bottom:none}tr:nth-child(even) td{background:#fbfaf4}
td.grade{font-weight:800}.del{border:2px solid var(--ink);background:var(--red);color:#fff;border-radius:8px;
padding:4px 10px;font-weight:700;cursor:pointer;box-shadow:2px 2px 0 var(--ink);font-family:inherit}
.empty{border:3px dashed var(--ink);border-radius:12px;padding:40px;text-align:center;color:var(--muted)}
.foot{color:var(--muted);font-size:.82rem;margin-top:18px;line-height:1.5}
"""


def roster_html(rows):
    studs = '<div class="studs"><i style="background:var(--red)"></i><i style="background:var(--yel)"></i>' \
            '<i style="background:var(--blu)"></i><i style="background:var(--grn)"></i></div>'
    head = (f"<!doctype html><html lang=en><head><meta charset=utf-8>"
            f"<meta name=viewport content='width=device-width,initial-scale=1'>"
            f"<meta name=robots content='noindex,nofollow'>"
            f"<title>Team roster</title><style>{ROSTER_CSS}</style></head><body>{studs}"
            f"<h1>Your team roster 🧱</h1>"
            f"<p class=sub>Every signup, newest first. This page is private (password-protected) and not indexed.</p>"
            f"<div class=bar><span class='pill count'>{len(rows)} signed up</span>"
            f"<a class='pill csv' href='/api/roster?format=csv'>Download CSV</a>"
            f"<a class='pill json' href='/api/roster?format=json'>JSON</a></div>")
    if not rows:
        return head + "<div class=empty>No signups yet. Share your flyer's QR code and watch them roll in. 🚀</div></body></html>"
    trs = []
    for r in rows:
        cells = "".join(
            f"<td class='{ 'grade' if k=='childGrade' else '' }'>{html.escape(str(r.get(k) or ''))}</td>"
            for k in ["ts"] + FIELDS
        )
        delbtn = (f"<td><form method=post action='/api/roster/delete' "
                  f"onsubmit=\"return confirm('Delete this signup? This cannot be undone.')\" style=margin:0>"
                  f"<input type=hidden name=id value='{r['id']}'>"
                  f"<button class=del type=submit>Delete</button></form></td>")
        trs.append("<tr>" + cells + delbtn + "</tr>")
    header = "".join(f"<th>{h}</th>" for h in
                     ["when", "parent", "email", "phone", "child", "grade", "notes", "source", ""])
    foot = ("<p class=foot>Privacy: this holds a child's first name + grade and a parent's contact info — "
            "the minimum to run a team. Tell families where their data lives, and delete it at season's end "
            "(the <b>Delete</b> button removes a row; the whole database is the single SQLite file at "
            f"<code>{html.escape(DB_PATH)}</code> on your box).</p>")
    return head + f"<table><thead><tr>{header}</tr></thead><tbody>{''.join(trs)}</tbody></table>" + foot + "</body></html>"


def roster_csv(rows):
    buf = io.StringIO()
    w = csv.writer(buf)
    w.writerow(["id", "ts"] + FIELDS)
    for r in rows:
        w.writerow([r["id"], r["ts"]] + [r.get(k, "") for k in FIELDS])
    return buf.getvalue()


# ── HTTP handler ─────────────────────────────────────────────────────────────────────────────────
class Handler(BaseHTTPRequestHandler):
    server_version = "LegoLeagueKit/0.1"

    # -- helpers ----------------------------------------------------------------------------------
    def _send(self, code, body=b"", ctype="application/json", extra=None):
        if isinstance(body, str):
            body = body.encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        # Same-origin in the shipped stack; permissive CORS so a separately-hosted static site can POST too.
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "POST, GET, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        for k, v in (extra or {}).items():
            self.send_header(k, v)
        self.end_headers()
        if self.command != "HEAD":
            self.wfile.write(body)

    def _json(self, code, obj):
        self._send(code, json.dumps(obj), "application/json")

    def _read_form(self):
        length = int(self.headers.get("Content-Length") or 0)
        if length <= 0:
            return {}
        if length > MAX_BODY_BYTES:
            return None  # too big → caller returns 413
        raw = self.rfile.read(length).decode("utf-8", "replace")
        return {k: (v[0] if v else "") for k, v in parse_qs(raw, keep_blank_values=True).items()}

    def _authed(self):
        """True if HTTP Basic credentials match ROSTER_USER/ROSTER_PASS (constant-time)."""
        hdr = self.headers.get("Authorization", "")
        if not hdr.startswith("Basic "):
            return False
        try:
            user, _, pw = base64.b64decode(hdr[6:]).decode("utf-8").partition(":")
        except Exception:  # noqa: BLE001
            return False
        return hmac.compare_digest(user, ROSTER_USER) and hmac.compare_digest(pw, ROSTER_PASS)

    def _require_roster_auth(self):
        """Returns True if the request may see the roster; otherwise writes the response and returns False."""
        if not (ROSTER_USER and ROSTER_PASS):
            self._json(503, {"ok": False,
                             "error": "Roster is disabled. Set ROSTER_USER and ROSTER_PASS to enable it."})
            return False
        if not self._authed():
            self._send(401, json.dumps({"ok": False, "error": "auth required"}),
                       "application/json", {"WWW-Authenticate": 'Basic realm="Team roster"'})
            return False
        return True

    def log_message(self, fmt, *args):  # quieter, single-line logs to stderr
        sys.stderr.write("%s - %s\n" % (self.address_string(), fmt % args))

    # -- routes -----------------------------------------------------------------------------------
    def do_OPTIONS(self):
        self._send(204, b"", "text/plain")

    def do_GET(self):
        path = urlparse(self.path).path
        if path in ("/api/health", "/health"):
            return self._json(200, {"ok": True, "signups": count_signups()})
        if path in ("/api/roster", "/api/roster/"):
            if not self._require_roster_auth():
                return
            rows = all_signups()
            fmt = (parse_qs(urlparse(self.path).query).get("format", [""])[0]).lower()
            if fmt == "json":
                return self._json(200, {"ok": True, "count": len(rows), "signups": rows})
            if fmt == "csv":
                return self._send(200, roster_csv(rows), "text/csv",
                                  {"Content-Disposition": "attachment; filename=roster.csv"})
            return self._send(200, roster_html(rows), "text/html; charset=utf-8")
        return self._json(404, {"ok": False, "error": "not found"})

    def do_HEAD(self):
        self.do_GET()

    def do_POST(self):
        path = urlparse(self.path).path
        if path in ("/api/signup", "/signup"):
            return self._handle_signup()
        if path in ("/api/roster/delete",):
            return self._handle_delete()
        return self._json(404, {"ok": False, "error": "not found"})

    def _handle_signup(self):
        form = self._read_form()
        if form is None:
            return self._json(413, {"ok": False, "error": "payload too large"})

        # Honeypot: real submits never include "website" (the front end omits it). A filled honeypot is
        # a bot — accept quietly (so it can't tell it was caught) but store nothing.
        if form.get("website", "").strip():
            return self._json(200, {"ok": True})

        rec = {k: (form.get(k, "") or "").strip() for k in FIELDS}
        if not rec["source"]:
            rec["source"] = "api"
        # Minimal validation — mirror the front end: a plausible parent email is the one hard requirement.
        if not EMAIL_RE.match(rec["parentEmail"]):
            return self._json(400, {"ok": False, "error": "a valid parentEmail is required"})
        if not (rec["childName"] or rec["parentName"]):
            return self._json(400, {"ok": False, "error": "childName or parentName is required"})

        rid = insert_signup(rec)
        notify_coach(rec, rid)
        return self._json(200, {"ok": True, "id": rid})

    def _handle_delete(self):
        if not self._require_roster_auth():
            return
        form = self._read_form() or {}
        rid = form.get("id", "")
        if not rid.isdigit():
            return self._json(400, {"ok": False, "error": "numeric id required"})
        delete_signup(int(rid))
        # A browser form POST → send it back to the roster; an API caller gets JSON.
        if "text/html" in (self.headers.get("Accept") or ""):
            return self._send(303, b"", "text/plain", {"Location": "/api/roster"})
        return self._json(200, {"ok": True, "deleted": int(rid)})


def main():
    init_db()
    roster_state = "enabled" if (ROSTER_USER and ROSTER_PASS) else "DISABLED (set ROSTER_USER/ROSTER_PASS)"
    email_state = "enabled" if (SMTP_HOST and COACH_EMAIL) else "off (set SMTP_HOST + COACH_EMAIL)"
    print(f"🧱 LEGO League signup API on :{PORT}  db={DB_PATH}  roster={roster_state}  email={email_state}",
          file=sys.stderr)
    ThreadingHTTPServer(("0.0.0.0", PORT), Handler).serve_forever()


if __name__ == "__main__":
    main()
