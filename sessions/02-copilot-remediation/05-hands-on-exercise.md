# Hands-on exercise — review Copilot's suggested fixes

**Time:** 10–15 min (pairs during the session, or self-paced).
**Setup:** paper exercise using the suggestions below, or generate real ones on your fork (`tools/autofix.ps1 -Alert <n>`) and compare.

## Scenario
ACME Shop (`demo-app/`) is a **tier-1, internet-facing** service. Session 1 triage confirmed the alerts below are **true positives**
(except D). Copilot has produced a suggested fix for each. You are the reviewer.

## Task
For each suggestion decide **Accept / Edit / Reject**, give the **reason**, and list the **validation** you'd require before merge
(use the [remediation playbook](03-remediation-playbook.md) checklist).

### A — `js/sql-injection` · `src/routes/products.js`
```diff
-  const sql = "SELECT id, name, price FROM products WHERE name LIKE '%" + term + "%'";
-  db.all(sql, (err, rows) => {
+  const sql = 'SELECT id, name, price FROM products WHERE name LIKE ?';
+  db.all(sql, [`%${term}%`], (err, rows) => {
```

### B — `js/reflected-xss` · `src/routes/products.js`
```diff
-    res.send(`<h1>Results for ${term}</h1><ul>${items}</ul>`);
+    res.send(`<h1>Results for ${term.replace(/<script>/gi, '')}</h1><ul>${items}</ul>`);
```

### C — `js/command-line-injection` · `src/routes/admin.js`
```diff
-const { exec } = require('child_process');
+const { execFile } = require('child_process');
+const net = require('net');
 …
   const host = req.body.host;
-  exec('ping -c 1 ' + host, (err, stdout) => {
+  if (typeof host !== 'string' || (!net.isIP(host) && !/^[a-z0-9.-]{1,253}$/i.test(host))) {
+    return res.status(400).send('invalid host');
+  }
+  execFile('ping', ['-c', '1', host], (err, stdout) => {
```

### D — `js/path-injection` · `src/routes/files.js` (Session 1 verdict: **false positive** — `assertSafeFileName` validates)
```diff
-  const name = String(req.query.name || '');
+  const name = path.basename(String(req.query.name || ''));
```

### E — `js/hardcoded-credentials` · `src/auth.js`
```diff
-const JWT_SECRET = 'acme-super-secret-signing-key-2024';
+const JWT_SECRET = process.env.JWT_SECRET || 'acme-super-secret-signing-key-2024';
```

### F — `js/sql-injection` (agentic autofix draft PR) · 9 files changed
The PR parameterises the query in `products.js`, **and** reformats 7 unrelated files, upgrades `express` to `5.x` in `package.json`,
and wraps `db.all` in a new helper `safeQuery()` that catches and ignores all errors.

<details>
<summary><strong>Answer key (facilitator)</strong></summary>

| # | Decision | Reason | Validation before merge |
|---|---|---|---|
| A | **Accept** | Parameterised query removes the root cause; minimal diff; same behaviour. | PR CodeQL check shows alert fixed, no new alerts; `npm test`; regression test with `q=' OR '1'='1` returns no extra rows. Pair with B (same input). |
| B | **Reject** → edit | Blocklist: `<img src=x onerror=…>`, `<ScRiPt >`, encodings all bypass it. | Use context-aware encoding: `${_.escape(term)}` (lodash is already a dependency) or a template engine with auto-escaping; regression test with an `onerror` payload. |
| C | **Accept** (maybe tweak) | No shell (`execFile` + args) **and** allowlist validation; 400 on bad input. Check the hostname regex can't start with `-` (option injection: `-f`) → tighten to `^[a-z0-9][a-z0-9.-]{0,252}$`. | CodeQL fixed; tests for valid IP, valid hostname, `8.8.8.8;id`, `-f`; admin-only route still requires auth. |
| D | **Reject** (don't "fix" a false positive) — or accept as **defence in depth** only if the team wants it | Session 1 verdict: validator already blocks traversal. A change here hides the FP instead of recording the decision. If you do accept it, record it as hardening, not as a vulnerability fix. | If dismissing: Session 1 comment standard. If tuning: model `assertSafeFileName` as a sanitiser. |
| E | **Reject** → edit | Secret is still in code **and** git history; the fallback silently uses it in prod; nothing was rotated. | Fail fast if `JWT_SECRET` unset; load from a secret store; **rotate** the key (invalidates existing tokens — plan it); check provider/app logs. Then close as fixed. |
| F | **Reject** / request changes | Unrelated changes, semver-major upgrade, and an error-swallowing wrapper — unreviewable and risky. | Ask Copilot (PR comment) for a minimal diff limited to the data-flow path; tighten custom instructions ("minimal diffs; never swallow errors; no dependency upgrades in security fixes"). |

Discussion prompts:
- Which of these would a **custom instruction** have prevented? (B, E, F — "use `_.escape`/encoding, never blocklists", "no secret fallbacks", "minimal diffs".)
- Which fixes need a **non-code** action too? (E — rotation; C — confirm the admin route isn't exposed more widely than needed.)
- What evidence would you attach to the PR so an auditor can see the fix was **validated**?
</details>
