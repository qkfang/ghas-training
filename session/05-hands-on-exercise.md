# Hands-on exercise — triage the ACME Shop backlog

**Time:** 10–15 min (self-paced after the session, or in pairs during it).
**Setup:** your fork of this repo with GHAS features enabled (see [`04-demo-script.md`](04-demo-script.md) Setup), or use the alert table below as a paper exercise.

## Scenario
ACME Shop (`demo-app/`) is a **tier-1, internet-facing** service handling customer orders. Rate limiting is enforced at the API gateway. `scripts/seed.js` is a developer-only CLI. You own the backlog.

## Task
For each alert, decide: **verdict** (TP / FP / N/A), **priority** (P0–P3), **action** (Fix / Tune / Dismiss + reason / Rotate), and write the **dismissal comment** where relevant (use the playbook standard).

| # | Source | Finding | Location |
|---|---|---|---|
| A | Code scanning | Database query built from user-controlled sources (`js/sql-injection`) | `src/routes/products.js` |
| B | Code scanning | Reflected cross-site scripting (`js/reflected-xss`) | `src/routes/products.js` |
| C | Code scanning | Uncontrolled command line (`js/command-line-injection`) | `src/routes/admin.js` |
| D | Code scanning | Uncontrolled data used in path expression (`js/path-injection`) | `src/routes/files.js` |
| E | Code scanning | Hard-coded credentials (`js/hardcoded-credentials`) | `src/auth.js` |
| F | Code scanning | Hard-coded credentials (`js/hardcoded-credentials`) | `test/auth.test.js` |
| G | Code scanning | Missing rate limiting (`js/missing-rate-limiting`) | `src/routes/reports.js` |
| H | Dependabot | `minimist` prototype pollution (critical) | runtime dependency, used only by `scripts/seed.js` |
| I | Dependabot | `lodash` (high) | runtime; app uses `_.chunk`, `_.escape` only |
| J | Dependabot | `semver` / `minimatch` ReDoS | **development** dependencies |
| K | Dependabot | `jsonwebtoken` (high) | runtime; used for auth |
| L | Secret scanning | ACME API key `acme_live_…` | `src/config/settings.js` |
| M | Secret scanning | ACME API key `acme_test_…` | `test/auth.test.js` |

<details>
<summary><strong>Answer key (facilitator)</strong></summary>

| # | Verdict | Priority | Action & rationale |
|---|---|---|---|
| A | TP | **P1** (P0 if data is sensitive) | Fix — parameterised query. Public, unauthenticated, no sanitiser. |
| B | TP | P1 | Fix — escape `term` (`_.escape`) or use a template engine with auto-escaping. Same root cause as A. |
| C | TP | **P0/P1** | Fix — use `execFile('ping', ['-c','1', host])` + validate host. Admin auth reduces likelihood, not impact (RCE). |
| D | FP (probably) | — | One-off → Dismiss **False positive** with evidence of `assertSafeFileName`. If this validator is used widely → **Tune** (model as barrier / refactor to `resolve`+`startsWith`). |
| E | TP | P1 | Fix — load from secret store/env, rotate the key (it's in history). **Never** "won't fix" without approval. |
| F | N/A | P3 | Dismiss **Used in tests** — verify file only under `test/` and key isn't used elsewhere. |
| G | TP, mitigated | P3 | Dismiss **Won't fix** (risk acceptance): `[RISK-ACCEPTED] gateway rate limit RL-7 | approver | review date | ticket`. Or add `express-rate-limit` if cheap. |
| H | TP, low exposure | P2/P3 | Upgrade (cheap patch). If not possible: **Risk is tolerable** — only trusted local CLI args reach it. Consider moving to devDependencies. |
| I | TP in package, not reachable | P2 | Prefer **upgrade** (non-breaking). Only if blocked: **Vulnerable code not used** with review date. |
| J | N/A | P3 | Let the **auto-triage preset** dismiss low-impact dev-scoped alerts; fix rest in a grouped dev security update. |
| K | TP | P1 | Upgrade to v9+ (semver-major — test auth flows). Auth library = high criticality. |
| L | TP | **P0** | **Rotate first**, move to secret store, then close **Revoked**. Check provider logs; it's in git history. |
| M | N/A | P3 | Close **Used in tests** after confirming the test key is invalid in all environments. |

Discussion prompts:
- Which alerts would you **tune** rather than dismiss if they appeared in 20 repos?
- Which dismissals need **security approval** under delegated dismissal?
- What would make you **reopen** F, H or I in six months?
</details>
