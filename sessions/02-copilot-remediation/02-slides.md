---
marp: true
theme: default
paginate: true
title: Remediating vulnerabilities with GitHub Copilot
---

<!-- _class: lead -->
# Remediating Vulnerabilities with GitHub Copilot
### Session 2 · Copilot Autofix, understanding, validating and shipping fixes

45 min · 35 min talk + 10 min hands-on demo

---

## Outcome for today

You will be able to:

1. Explain what **Copilot Autofix** and **agentic autofix** do — and when to use each
2. Use Copilot to **understand** a vulnerability before changing code
3. **Generate and validate** a suggested fix like any other code change
4. Fit Copilot into the **remediation workflow** — PR, backlog and campaigns

---

## Where we left off (Session 1)

- Alerts are **prioritised** by risk and **investigated** to a verdict
- Resolution order: **Fix → Tune → Dismiss**
- Today: make **Fix** the cheap, default option

> If fixing is cheap, fewer alerts get dismissed — and fewer risk acceptances need governing.

---

## GitHub Copilot Autofix

- Uses an LLM + the **CodeQL analysis** (data-flow path, rule help) + surrounding code
- Produces a **suggested code change** and a **natural-language explanation**
- Enabled **by default** wherever CodeQL runs (default or advanced setup) — admins can disable it
- Available on all public repos; private/internal repos need **GitHub Code Security**
- Copilot Autofix suggestions **don't consume AI credits**

---

## Two flavours of autofix

| | **Copilot Autofix** | **Agentic autofix** (assign to Copilot) |
|---|---|---|
| Unit of work | One alert → one suggested change | One or more alerts → one draft PR |
| How | *Generate fix* on alert / PR comment | **Assign** alert(s) to Copilot |
| Context | Alert + nearby code | Explores the codebase, validates by re-running CodeQL |
| Enablement | On by default with CodeQL | Org owner / security manager enables (admin on personal public repos) |
| Cost | No AI credits | Code Security AI credits + Actions minutes |
| Custom instructions | — | Honoured (`.github/copilot-instructions.md`, `*.instructions.md`) |

---

## Where autofix shows up

- **Pull requests** — new alert in the diff → Autofix suggestion as a review comment
- **Alert page** (backlog) → **Generate fix** → **Create PR with fix**
- **Security campaigns** → Autofix suggested automatically; assign up to 25 alerts to Copilot
- **REST API** → `POST …/code-scanning/alerts/{n}/autofix` then `…/autofix/commits`

> Same engine, four entry points — pick the one that matches the stream (gate vs burn-down).

---

## Know the limits

- **Not every alert** gets a suggestion — use the `autofix:supported` filter
- Suggestions can be **incomplete**, change behaviour, or add a **dependency**
- Agentic autofix **can't confirm** fixes for `security-extended`, custom queries or third-party tools
- Code-only: it **cannot** rotate a secret, change infrastructure or accept risk
- Non-deterministic — regenerate if the first answer is weak

> Treat every suggestion as a PR from a capable but new teammate.

---

## Understand before you fix

Why bother if Copilot writes the fix?

- You can't **review** a fix you don't understand
- The alert may be a **false positive** (Session 1) — a "fix" would be noise
- The same **root cause** often lives elsewhere — fix the class, not the instance
- Learning the pattern prevents the **next** alert

---

## Using Copilot to understand a vulnerability

1. **Rule help + Show paths** — source → steps → sink (ground truth from CodeQL)
2. **Autofix explanation** — *why* the code is vulnerable and *what* the change does
3. **Copilot Chat** (github.com or IDE, with the file open):
   - "Explain this `js/sql-injection` alert and how an attacker would exploit `GET /products/search`."
   - "Where else in this repo is user input concatenated into SQL?"
   - "What input would prove this is exploitable? Write a request I can run locally."
4. Decide: **true positive?** If not — back to the Session 1 dismissal path

---

## Good prompts vs weak prompts

| Weak | Strong |
|---|---|
| "Fix this" | "Fix this SQL injection using parameterised queries with the existing `db` API; keep the response format unchanged" |
| "Is this safe?" | "Trace `req.body.host` to `exec`. Is there any validation? What does `host=8.8.8.8;id` do?" |
| "Explain" | "Explain the CWE, the attacker preconditions, and why `_.escape` on output doesn't stop the SQLi" |

> Give Copilot the **constraint** (API, style, behaviour to preserve) and the **evidence** (alert, path).

---

## Generating a suggested fix

**Alert page → Generate fix**

- Read the **explanation** first, then the **diff**
- Check which files and lines change — anything outside the data-flow path?
- **Create PR with fix** (draft) → normal branch, CI and review apply
- Or **commit to an existing branch** if you're already working nearby

**In a PR** — accept the suggestion inline or *Commit suggestion*, then re-run checks

---

## Validate like any other change

| Check | How |
|---|---|
| **Root cause fixed?** | Data no longer reaches the sink unsanitised (param query, `execFile`, encoding) |
| **Alert closes?** | CodeQL check on the PR shows the alert **fixed**; no new alerts introduced |
| **Behaviour preserved?** | Unit / integration tests pass; add a **regression test** with the exploit payload |
| **Side effects?** | New dependency? API contract change? Error handling? Performance? |
| **Complete?** | Same pattern in sibling code paths (e.g., SQLi *and* XSS on `term`) |
| **Owned?** | CODEOWNERS / security reviewer approves — **a human merges** |

---

## Red flags in a suggested fix

- 🚩 **Blocklist** validation (`replace(/;/g, '')`) instead of safe APIs / allowlists
- 🚩 Secret moved to `process.env.X || 'old-hardcoded-value'` — still hard-coded, still **unrotated**
- 🚩 Fix silences the **tool**, not the bug (renaming, wrapping in a no-op function)
- 🚩 Catches and swallows errors to "make it pass"
- 🚩 Changes far outside the data-flow path or adds an unknown package

> Reject or edit — then regenerate with a better prompt.

---

## Example: command injection

```js
// Before — js/command-line-injection
exec('ping -c 1 ' + host, cb);

// 🚩 Weak suggestion — blocklist, still a shell
exec('ping -c 1 ' + host.replace(/[;&|`$]/g, ''), cb);

// ✅ Strong fix — no shell + allowlist validation
if (!net.isIP(host) && !/^[a-z0-9.-]{1,253}$/i.test(host)) return res.status(400).end();
execFile('ping', ['-c', '1', host], cb);
```

---

## Copilot in the remediation workflow

```text
 PR stream (gate)                        Backlog stream (burn-down)
 ───────────────                         ──────────────────────────
 new alert in PR                         prioritised alert (P0–P3)
   └► Autofix comment in PR                └► understand (Chat + paths)
       └► accept / edit                        ├► Generate fix → draft PR
           └► CodeQL re-runs                    ├► Assign to Copilot → draft PR
               └► merge                         └► IDE Copilot (complex / multi-file)
                                                    └► validate → review → merge
```

---

## Choosing the right tool

| Situation | Use |
|---|---|
| New alert in my PR | **Autofix suggestion** inline in the PR |
| Single backlog alert, small change | **Generate fix → Create PR** |
| Several related alerts, multi-file, needs tests | **Assign to Copilot** (agentic) |
| Design change, unfamiliar code, refactor | **Copilot Chat / agent mode in the IDE** |
| Dependabot major upgrade breaks build | Copilot Chat on the failing tests / API changes |
| Secret | **Rotate first** — Copilot can help remove it from code, not revoke it |

---

## Make Copilot fix it *your* way

- **Custom instructions**: secure-coding rules for the repo/path
  (e.g. `.github/instructions/demo-app-security.instructions.md`)
  - "Use parameterised queries via `db.all(sql, params)`"
  - "Never use `exec`; use `execFile` with an argument array"
  - "Add a `node:test` regression test for every security fix"
- Agentic autofix and Copilot coding agent **honour** these instructions
- Encode org patterns once → consistent fixes across repos

---

## Guardrails

- **Rulesets**: require PR review + passing **CodeQL** check before merge
- **Code owners / security reviewers** on sensitive paths
- Autofix PRs are **drafts** — no auto-merge for security fixes
- Track: suggestions generated vs **accepted vs edited vs rejected**
- Cost awareness: agentic sessions use **AI credits + Actions minutes**

> Copilot shortens time-to-fix; it doesn't move accountability.

---

## Metrics that show it's working

| Measure | Signal |
|---|---|
| **MTTR** before/after Autofix | Faster fixes? |
| Alerts **fixed in PR** vs reaching default branch | Gate working? |
| Autofix **acceptance rate** (and edit rate) | Suggestion quality / trust |
| Fix vs **dismiss** ratio | Fixing now cheaper than dismissing? |
| Reopened / regressed alerts | Fix quality |

---

<!-- _class: lead -->
# Hands-on demo (10 min)
`demo-app/` — fix real alerts with Copilot

1. Understand the SQL injection with Copilot · 2. Generate & review Autofix
3. Validate in the PR · 4. Command injection: weak vs strong fix
5. Assign to Copilot / script it with the API

---

## Takeaways

1. **Understand first** — Copilot explains, CodeQL proves, *you* decide
2. **Autofix is a suggestion** — review it like any teammate's PR
3. **Validate**: alert closes, tests pass, regression test added, no new risk
4. **Right tool per stream** — PR autofix for new, Generate/Assign for backlog, IDE for complex
5. **Encode your patterns** in custom instructions; keep humans merging

📄 Handout: `sessions/02-copilot-remediation/03-remediation-playbook.md` · 🧪 Practice: `demo-app/` + `tools/autofix.ps1`

➡️ Next: **Session 3** — security campaigns to remediate at scale
