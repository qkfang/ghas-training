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
│  └─ utils/validate.js    # the validator CodeQL doesn't model
├─ test/auth.test.js       # hard-coded key + fake test API key (used in tests)
├─ scripts/seed.js         # dev CLI using minimist (Dependabot context)
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

Custom pattern to create in repo settings: **Name** `ACME API key`, **Secret format** `acme_(live|test)_[A-Za-z0-9]{24}`.

`npm audit` at the time of writing reports 20 advisories (4 critical, 11 high) across direct and transitive packages.
