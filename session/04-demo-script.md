# Hands-on demo script (10 minutes)

Repository: `qkfang/ghas-training` · App: [`demo-app/`](../demo-app) · Tools: [`tools/`](../tools)

## Setup (do the day before — ~20 min)

```powershell
# 1. Enable Dependabot alerts, secret scanning, push protection (add -EnableDependabotSecurityUpdates for fix PRs)
./tools/enable-ghas.ps1 -Repo qkfang/ghas-training -EnableDependabotSecurityUpdates

# 2. Create the custom secret pattern (UI): Settings > Advanced Security > Secret scanning > Custom patterns
#    Name: ACME API key     Secret format: acme_(live|test)_[A-Za-z0-9]{24}
#    Dry run, then Publish — secret scanning back-fills alerts for existing commits.

# 3. Run CodeQL (advanced setup using .github/codeql/codeql-config.yml, security-extended suite)
gh workflow run codeql.yml -R qkfang/ghas-training
gh run watch -R qkfang/ghas-training

# 4. Check what you've got, then stage good/bad dismissals for the audit segment
./tools/alert-report.ps1
./tools/seed-dismissals.ps1
```

Expected alerts are listed in [`demo-app/README.md`](../demo-app/README.md). If an expected CodeQL alert does not appear
(query behaviour changes between CodeQL releases), adapt the talking point — the triage logic is the lesson.

**Browser tabs to pre-open** (zoom 125%):
1. Security and quality → Overview
2. Code scanning alerts (filter `is:open`)
3. The `js/sql-injection` alert
4. The `js/path-injection` alert
5. Dependabot alerts (sorted *Most important*)
6. Secret scanning alerts
7. Terminal in repo root

**Reset after the session:** `./tools/seed-dismissals.ps1 -Reset`, reopen anything dismissed live, close the Autofix PR without merging (so the demo is repeatable).

---

## Segment 1 — Prioritise the backlog (2 min)

1. Open **Security and quality → Code scanning**. Point out the count; ask "where would you start?"
2. Apply filter `is:open severity:critical,high`. Then show **Dependabot**, filter `is:open scope:runtime severity:critical,high`, sort **Most important**; point to the EPSS value on one alert.
3. Switch to terminal:
   ```powershell
   ./tools/alert-report.ps1
   ```
   Talk track: *"One list, three sources, starting priority from our playbook rules. The **secret** and the **command injection** are P0, `minimist` is critical but dev-tooling only — a human adjusts the tier using context the tool doesn't have."*

## Segment 2 — Investigate & fix a true positive (3 min)

1. Open the **SQL injection** alert in `demo-app/src/routes/products.js`.
2. Click **Show paths**: `req.query.q` (source) → string concatenation → `db.all(sql)` (sink).
   - Source attacker-controlled? Yes — public `GET /products/search`.
   - Sanitiser? None. Reachable? Route mounted in `server.js`, no auth. → **True positive, P1**.
3. Mention the **reflected XSS** on the same line of input — fix the class, not just the instance.
4. Click **Generate fix** (Copilot Autofix) → walk through the parameterised query → **Create PR with fix** (draft).
   - Alternative if enabled: **Assign to Copilot** (agentic autofix) and show the PR it opens.
   - Talk track: *"Autofix is a suggestion — the reviewer still owns correctness and tests."*

## Segment 3 — Handle a false positive properly (2 min)

1. Open the **path injection** alert in `demo-app/src/routes/files.js`.
2. Show paths: `req.query.name` → `path.join` → `res.sendFile`. Then open `src/utils/validate.js`:
   `assertSafeFileName` throws unless the name matches `^[a-z0-9-]{1,64}\.pdf$` — no `/`, no `..`.
3. Decision tree: real? **No** (validation the tool doesn't model). Systemic? Discuss:
   - one-off → dismiss with evidence;
   - common validator used everywhere → **tune** (model the validator as a barrier/sanitiser, or refactor to a pattern CodeQL recognises, e.g. `path.resolve` + `startsWith(DOCS_DIR)` check).
4. Dismiss live: **Dismiss alert → False positive** with comment:
   ```text
   [FP] name validated by assertSafeFileName() /^[a-z0-9-]{1,64}\.pdf$/ (no / or ..) before sendFile | approver: @sec-lead | review: 2027-05 | SEC-142
   ```
   *If CodeQL did not raise this alert, use the `js/missing-rate-limiting` alert on `reports.js` instead and dismiss as **Won't fix** with a compensating-control comment (gateway rate limit) — showing risk acceptance vs FP.*

## Segment 4 — Dependencies & a secret (2 min)

1. **Dependabot → lodash**: open the advisory (e.g. prototype pollution in `zipObjectDeep` / command injection in `template`).
   - Code search: the app uses only `_.chunk` and `_.escape`. Tempting to dismiss as **Vulnerable code not used**…
   - …but a patched version exists and it's a non-breaking upgrade → **fix it** (Dependabot security update PR). *"Dismiss only when fixing is expensive."*
2. **Dev-scoped alerts** (`semver`, `minimatch`): show the auto-triage preset *Dismiss low impact issues for development-scoped dependencies* in **Settings → Advanced Security → Dependabot rules**; filter `resolution:auto-dismissed` if any were auto-dismissed. *"Noise removed by rule, still auditable, auto-reopens if scope changes."*
3. **Secret scanning → ACME API key** in `src/config/settings.js` (`acme_live_…`):
   - Contain first: rotate at provider → move to env/secret store → close as **Revoked**.
   - Compare with the `acme_test_…` key in `test/auth.test.js` → **Used in tests** *only after* confirming it's not valid anywhere.

## Segment 5 — Audit dismissed findings (1 min)

```powershell
./tools/alert-report.ps1 -DismissedOnly
```

Walk the flags:
- `js/hardcoded-credentials` in **src/auth.js** dismissed as *won't fix* — "not an issue" → `WEAK-JUSTIFICATION`, `NO-APPROVAL-OR-REVIEW-DATE`. It's a real production signing key → **reopen** in UI.
- Same rule in **test/auth.test.js** dismissed as *used in tests* with evidence → good example, no flags.
- `minimatch` *tolerable risk* "dev only" → weak justification; better handled by the auto-triage rule.

Close: *"Dismissed isn't done. If the reason wouldn't convince an auditor in a year, reopen it."*

---

## Fallbacks
- **No network / UI changed**: use pre-captured screenshots; run `alert-report.ps1` output saved from rehearsal.
- **Autofix unavailable**: show the manual fix:
  ```js
  db.all('SELECT id, name, price FROM products WHERE name LIKE ?', [`%${term}%`], ...)
  ```
- **Running long**: skip Segment 4 step 2; keep Segment 5 — it's the session's key message.

## Optional attendee follow-along
Attendees can fork the repo, enable Actions + GHAS features on their fork (`tools/enable-ghas.ps1 -Repo <you>/ghas-training`) and work through [`05-hands-on-exercise.md`](05-hands-on-exercise.md) after the session.
