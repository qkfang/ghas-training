# ACME Shop demo app — ⚠️ intentionally vulnerable

A tiny Express + SQLite API seeded with a **realistic mix** of true positives, false positives,
test-only findings, risk-accepted findings and vulnerable dependencies, shared by all three training sessions
([`../sessions`](../sessions)): triage (1), Copilot remediation (2) and security campaigns (3). **Do not deploy.** All secrets are fake.

The app is designed to be **scanned**, not run. (Running is optional: `npm install && npm start` — the pinned
`sqlite3@5.0.0` may need native build tools on newer Node versions.)

## Layout

```text
demo-app/
├─ src/
│  ├─ server.js            # wires routes
│  ├─ auth.js              # hard-coded JWT key (TP)
│  ├─ db.js                # in-memory sqlite
│  ├─ config/settings.js   # fake "live" ACME API key (secret scanning, custom pattern)
│  ├─ routes/products.js   # SQL injection + reflected XSS (TP), safe parameterised query (contrast)
│  ├─ routes/files.js      # path injection guarded by custom validator (likely FP)
│  ├─ routes/admin.js      # command injection behind admin auth (TP)
│  ├─ routes/reports.js    # missing rate limiting, mitigated at gateway (risk accept)
│  ├─ routes/orders.js     # [team-checkout] SQLi (WHERE + ORDER BY), reflected XSS, stack trace exposure   ┐
│  ├─ routes/reviews.js    # [team-catalog]  SQLi in INSERT, reflected XSS                                  │ Session 2/3
│  ├─ routes/account.js    # [team-accounts] open redirect, reflected XSS, path traversal (TP)              │ demo content
│  ├─ routes/integrations.js # [team-platform] code injection (eval), SSRF, command injection, regex injection ┘
│  ├─ config/partners.js   # 2nd fake "live" ACME API key (secret campaign)
│  └─ utils/validate.js    # the validator CodeQL doesn't model
├─ test/auth.test.js       # hard-coded key + fake test API key (used in tests)
├─ scripts/seed.js         # dev CLI using minimist (Dependabot context)
├─ scripts/backfill.js     # 3rd fake "live" ACME API key (secret campaign)
├─ public/vendor/…min.js   # vendored DOM XSS, excluded via paths-ignore (tuning example)
├─ package.json            # vulnerable pins: express, jsonwebtoken, lodash, minimist, sqlite3 (+ dev: semver, minimatch)
└─ package-lock.json
```

## Expected alerts (answer key)

Scanning uses `.github/workflows/codeql.yml` with the **security-extended** suite via `.github/codeql/codeql-config.yml`.
Exact CodeQL results can vary between releases — treat this as the intended design.

| Source | Expected finding | File | Intended triage |
|---|---|---|---|
| CodeQL | `js/sql-injection` | `src/routes/products.js` | True positive → fix (Autofix) |
| CodeQL | `js/reflected-xss` | `src/routes/products.js` | True positive → fix |
| CodeQL | `js/command-line-injection` | `src/routes/admin.js` | True positive → fix (P0/P1) |
| CodeQL | `js/path-injection` | `src/routes/files.js` | False positive → dismiss with evidence / tune |
| CodeQL | `js/hardcoded-credentials` | `src/auth.js` | True positive → fix + rotate |
| CodeQL | `js/hardcoded-credentials` | `test/auth.test.js` | Used in tests |
| CodeQL | `js/missing-rate-limiting` | `src/routes/reports.js` (and others) | Won't fix (compensating control) or fix |
| CodeQL | *(none)* | `public/vendor/legacy-widget.min.js` | Suppressed by `paths-ignore` — tuning |
| Dependabot | `minimist`, `lodash`, `jsonwebtoken`, `express` (+ transitive `body-parser`, `qs`, `path-to-regexp`, `send`, `cookie`), `sqlite3` (+ transitive `tar`, …) | `package-lock.json` | Prioritise by scope / EPSS / reachability |
| Dependabot | `semver`, `minimatch` (dev) | `package-lock.json` | Auto-triage preset / P3 |
| Secret scanning (custom pattern) | `acme_live_…` | `src/config/settings.js` | Rotate → close Revoked (P0) |
| Secret scanning (custom pattern) | `acme_test_…` | `test/auth.test.js` | Used in tests |

### Session 2 & 3 demo content (verified on `qkfang/ghas-training`, CodeQL run on commit `57df874`)

All default-suite CodeQL rules, so **Copilot Autofix** suggests fixes and **agentic autofix** can validate them.
Files carry a fictional owning team so campaigns can be discussed per team.

| Rule | Severity | File (team) | Session 2 use | Session 3 campaign theme |
|---|---|---|---|---|
| `js/code-injection` (`eval`) | critical | `routes/integrations.js` (platform) | Autofix headline demo — fix must remove `eval` | Injection |
| `js/request-forgery` (SSRF) | critical | `routes/integrations.js` (platform) | Review: allowlist of hosts vs. "block 169.254.*" | — (standalone P0/P1) |
| `js/command-line-injection` | critical | `routes/integrations.js` (platform), `routes/admin.js` | Weak (blocklist) vs strong (`execFile`) fix | Injection |
| `js/sql-injection` ×3 | high | `routes/orders.js` ×2 (checkout), `routes/reviews.js` (catalog) | ORDER BY can't be parameterised → needs allowlist; assign several to Copilot | Injection |
| `js/reflected-xss` ×3 | high | `routes/orders.js`, `routes/reviews.js`, `routes/account.js` | Encoding fix (`_.escape`) | XSS (CWE-79) |
| `js/xss-through-exception` | medium | `routes/orders.js` (`res.send(err.stack)`) | Autofix also removes stack-trace leakage | XSS (CWE-79) |
| `js/path-injection` | high | `routes/account.js` (accounts) | True-positive contrast with `files.js` (FP) | — |
| `js/server-side-unvalidated-url-redirection` | medium | `routes/account.js` (accounts) | Allowlist / relative-path-only redirect | — |
| `js/regex-injection` | high | `routes/integrations.js` (platform) | Escape input or use `includes` | — |
| `js/missing-rate-limiting` (more instances) | high | new routes | Noise / tuning (Session 1) | Excluded from campaigns — tune centrally |
| Secret scanning (custom pattern) `acme_live_…` ×3 | — | `config/settings.js`, `config/partners.js`, `scripts/backfill.js` | Rotate first; Copilot can't revoke | Secret campaign (public preview) |

Resulting campaign scopes in this repo: **Injection** = 7 alerts (4 SQLi, 2 command, 1 code injection) · **XSS (CWE-79)** = 5 alerts · **Secrets** = 3 live keys.

Custom pattern to create in repo settings: **Name** `ACME API key`, **Secret format** `acme_(live|test)_[A-Za-z0-9]{24}`.

`npm audit` at the time of writing reports 20 advisories (4 critical, 11 high) across direct and transitive packages.
