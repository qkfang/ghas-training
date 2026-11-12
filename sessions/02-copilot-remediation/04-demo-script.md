# Hands-on demo script (10 minutes) — Remediating with GitHub Copilot

Repository: `qkfang/ghas-training` · App: [`demo-app/`](../../demo-app) · Tools: [`tools/autofix.ps1`](../../tools/autofix.ps1)

## Setup (the day before — ~15 min)

```powershell
# 1. Session 1 setup must be done: GHAS enabled, CodeQL has run, alerts exist.
./tools/alert-report.ps1                      # confirm js/sql-injection, js/reflected-xss, js/command-line-injection are open

# 2. Find the alert numbers you'll use
gh api "repos/qkfang/ghas-training/code-scanning/alerts?state=open&per_page=100" `
  --jq '.[] | select(.rule.id | test("sql-injection|reflected-xss|command-line-injection|code-injection|request-forgery")) | [.number, .rule.id, .most_recent_instance.location.path] | @tsv'

# 3. Fallback: pre-generate an autofix for the SQL injection alert and screenshot it (does not commit anything)
./tools/autofix.ps1 -Alert <sqli#>
```

- Confirm **Copilot Autofix** is not disabled (Settings → Advanced Security → Code scanning).
- *Optional:* enable **agentic autofix** if you'll show *Assign to Copilot* (org setting, or repo setting for an eligible personal public repo).
- Open [`.github/instructions/demo-app-security.instructions.md`](../../.github/instructions/demo-app-security.instructions.md) in a tab — it's the custom instructions Copilot will follow.

**Browser tabs to pre-open** (zoom 125%):
1. The `js/sql-injection` alert (`demo-app/src/routes/products.js`)
2. The `js/command-line-injection` alert (`demo-app/src/routes/admin.js`)
3. The `js/code-injection` alert (`demo-app/src/routes/integrations.js`) — backup headline if time allows
4. Copilot Chat on github.com (or VS Code with the repo open)
5. Pull requests list
6. Terminal in repo root

All demo alerts and their intended use are listed in [`demo-app/README.md`](../../demo-app/README.md) (section *Session 2 & 3 demo content*).

**Reset after the session:** close (don't merge) any `autofix/*` PRs and delete their branches so the alerts stay open for the next run:

```powershell
gh pr list -R qkfang/ghas-training --search "head:autofix/" --json number --jq '.[].number' |
  ForEach-Object { gh pr close $_ -R qkfang/ghas-training --delete-branch }
```

---

## Segment 1 — Understand the vulnerability with Copilot (2 min)

1. Open the **SQL injection** alert. Show **rule help** and **Show paths**: `req.query.q` → string concatenation → `db.all(sql)`.
2. Ask Copilot Chat (with `demo-app/src/routes/products.js` in context):
   ```text
   Explain the js/sql-injection alert in demo-app/src/routes/products.js. What is the source, the sink,
   and what request would an attacker send to dump all products? Is _.escape on the output relevant?
   ```
3. Point out: Copilot's answer **agrees with the CodeQL path** (ground truth) and adds the exploit (`q=' OR '1'='1`) and the insight that `_.escape` only protects HTML output, not SQL. → **True positive**, proceed to fix.
4. Follow-up prompt: *"Where else in demo-app is user input concatenated into a query or shell command?"* → it should surface `orders.js`, `reviews.js`, `admin.js` and `integrations.js` — "fix the class, not the instance". Show the code scanning list filtered `is:open rule:js/sql-injection` (4 alerts).

## Segment 2 — Generate & review Copilot Autofix (2 min)

1. On the alert, click **Generate fix**. While it runs: *"No AI credits for this — it's a single suggested change."*
2. Read the **explanation first**, then the diff. Expected shape:
   ```js
   const sql = 'SELECT id, name, price FROM products WHERE name LIKE ?';
   db.all(sql, [`%${term}%`], (err, rows) => { … });
   ```
3. Review out loud with the checklist: root cause removed ✅ · only the data-flow lines changed ✅ · no new dependency ✅ · **but** `term` is still reflected unescaped in `<h1>` → the **reflected XSS** alert on the same input remains.
4. Click **Create PR with fix** (draft).

## Segment 3 — Validate in the PR (2 min)

1. On the draft PR, open the **Files changed** tab. Edit (or ask Copilot to edit) to also escape the heading: `` `<h1>Results for ${_.escape(term)}</h1>` `` — fixing both alerts in one PR.
2. Show the **CodeQL** check on the PR: the SQL injection (and XSS, after the edit) appear as **fixed**; no new alerts.
3. Validation talk track — tick the playbook checklist:
   - tests: `npm test` (and propose a regression test using the exploit payload from Segment 1);
   - behaviour: same response shape;
   - owner: a human approves — *"Autofix is a teammate's PR, not a merge button."*
4. Leave the PR as draft (reset step closes it).

## Segment 4 — Command injection: weak vs strong fix (2 min)

1. Open the **command injection** alert in `admin.js`: `req.body.host` → `exec('ping -c 1 ' + host)`.
2. Click **Generate fix** and compare with slide 14:
   - 🚩 if it suggests stripping characters (`replace(/[;&|]/g, '')`) → **edit or reject**: blocklist, still a shell;
   - ✅ target: `execFile('ping', ['-c', '1', host])` **plus** host validation (`net.isIP(host)` or a strict hostname regex) → 400 on invalid input.
3. Talk track: *"Admin auth lowers likelihood, not impact. And this is where custom instructions help — our instructions file says 'never use `exec`; use `execFile` with an argument array and allowlist validation'."* Show the instructions file.

## Segment 5 — Scale it: assign to Copilot / script it (2 min)

**Option A — agentic autofix (if enabled):** filter `is:open rule:js/sql-injection`, select the **three** alerts in `orders.js` / `reviews.js`, and **Assign to Copilot** (one session → one draft PR). Show the agent session and (if time) the PR.
Review point: the **ORDER BY** injection in `orders.js` can't be fixed with a bound parameter — check Copilot used an **allowlist** of sortable columns. It honours the custom instructions and validates by re-running CodeQL.
*Talk track: "This repo uses `security-extended`; agentic autofix can only confirm fixes for the default code scanning suite — rules like missing-rate-limiting won't be validated."*

**Option B — REST API:**
```powershell
./tools/autofix.ps1 -Alert <code-injection#> -CreatePR      # eval() in integrations.js — fix must remove eval, not filter it
```
Walk the output: request autofix → poll status → commit to `autofix/alert-<n>` → draft PR. *"Useful for champions batching fixes — every PR still gets reviewed."*

Close: *"Copilot made fixing cheap. Next session: how to organise hundreds of these across teams with security campaigns."*

---

## Fallbacks
- **Autofix not generated / unsupported**: use the screenshot from setup, or show the manual fix:
  ```js
  db.all('SELECT id, name, price FROM products WHERE name LIKE ?', [`%${term}%`], (err, rows) => { … });
  ```
- **Copilot Chat unavailable**: read the Autofix explanation aloud — it covers the "why".
- **Agentic autofix disabled**: use Option B, or show the setting and explain enablement/cost.
- **Running long**: skip Segment 5.

## Optional attendee follow-along
Fork the repo, enable GHAS features (`tools/enable-ghas.ps1 -Repo <you>/ghas-training`), run CodeQL, then work through [`05-hands-on-exercise.md`](05-hands-on-exercise.md).
