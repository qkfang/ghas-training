---
marp: true
theme: default
paginate: true
title: Prioritising, investigating & managing GHAS alerts
---

<!-- _class: lead -->
# Prioritising, Investigating & Managing GHAS Alerts
### Session 1 · Including false positives and dismissed findings

45 min · 35 min talk + 10 min hands-on demo

---

## Outcome for today

You will be able to:

1. **Prioritise** alerts by real risk — not by count or severity alone
2. **Investigate** an alert to a defensible true / false positive decision
3. **Resolve** it the right way: Fix → Tune → Dismiss (with evidence)
4. **Govern** dismissed findings so they stay honest over time

---

## The problem: alert fatigue

- Hundreds of open alerts → teams either **ignore everything** or **dismiss everything**
- Both outcomes leave exploitable risk in production
- "Closed alerts" is a vanity metric — **risk reduced** is the goal

> A good process answers three questions: *What do I look at first? How do I decide? How do I record the decision?*

---

## The alert landscape

| | Code scanning | Dependabot | Secret scanning |
|---|---|---|---|
| Finds | Flaws in **your code** | Known vulns in **dependencies** | **Credentials** in code/history |
| Key signals | Security severity, data-flow path, rule precision | CVSS, **EPSS**, scope, patch available, direct/transitive | **Validity**, provider, location, bypass |
| Auto-closes? | Yes — "Fixed" when no longer detected | Yes — when upgraded | **No** — must rotate & close |

---

## Where alerts surface

- **Pull requests** — code scanning annotations, Dependabot review, push protection at `git push`
- **Repository** → *Security and quality* tab → code scanning / Dependabot / secret scanning
- **Organisation** → *Security overview* — cross-repo risk, coverage, trends, campaigns
- **API / webhooks** → SIEM, ticketing, custom reports

---

## What "severity" means

- **Code scanning:** *security severity* (Critical/High/Medium/Low) is derived from CVSS of CVEs mapped to the rule's CWE — a property of the **rule**, not your app
- **Dependabot:** CVSS of the **advisory** — worst-case, context-free
- **Secrets:** no severity — a live credential is almost always top priority

> Severity tells you *how bad it could be*, not *how likely it is here*.

---

## Prioritise: the risk model

# Risk = Severity × Exploitability × Exposure × Criticality

| Factor | Ask | GHAS signal |
|---|---|---|
| Severity | How bad if exploited? | Security severity / CVSS |
| Exploitability | Can an attacker reach it? | Data-flow path, **EPSS**, KEV, secret **validity** |
| Exposure | Is it running where attackers are? | Runtime vs dev scope, test code, production context / custom properties |
| Criticality | What's at stake? | Repo custom properties (tier, data class) |

---

## Two streams, two strategies

**New alerts (in PRs)** → *Gate*
- Rulesets: code scanning merge protection, push protection
- Cheapest time to fix; Copilot Autofix suggests a fix inline

**Backlog (default branch)** → *Burn down*
- Order by priority tier + SLA
- Group by theme → security campaigns
- Track trend, not just totals

> Stop the bleeding first, then clean up.

---

## Priority tiers (example — align to your policy)

| Tier | Typical criteria | Example SLA |
|---|---|---|
| **P0** | Active/unknown secret · Critical/High, reachable, internet-facing · KEV / high EPSS | 24–72 h |
| **P1** | High in production runtime · Critical with limited exposure | 7–14 days |
| **P2** | Medium · High in internal/non-exposed apps | 30–60 days |
| **P3** | Low · dev-scope · test code | 90 days / campaign |

---

## Cut noise before humans see it

- **Dependabot auto-triage**: GitHub preset dismisses low-impact alerts in npm **dev** dependencies; custom rules by severity, package, CWE, scope…
- **CodeQL config**: `paths-ignore` vendored/generated code; choose `default` vs `security-extended` suites deliberately
- **Filters**: "only alerts in application code", `scope:runtime`, `severity:critical,high`, `validity:active`
- **Ownership**: custom properties + teams so alerts land with the right people

---

## Useful filters

```text
Code scanning   is:open severity:critical,high  autofilter:true
Dependabot      is:open scope:runtime severity:critical,high has:patch
Secret scanning is:open validity:active
```

Sort Dependabot by **Most important** — combines severity, EPSS, scope and more.

---

## Investigate: code scanning

1. Read the **rule help** — what's the vulnerability class?
2. **Show paths**: source → steps → sink
3. Ask:
   - Is the **source** really attacker-controlled?
   - Is there **validation/sanitisation** the tool can't see?
   - Is the **sink** reachable in a deployed path?
4. Check history: introduced in which PR? Same pattern elsewhere?
5. Use **Copilot Autofix** explanation as a second opinion — not proof

---

## Investigate: Dependabot

- Is the **vulnerable function/feature** actually called?
- **Runtime or development** scope? Direct or **transitive** (dependency graph shows the path)?
- **Patched version** available? Semver-major (breaking)?
- **EPSS** — likelihood of exploitation in the next 30 days
- Is the input that triggers it **attacker-controlled** in your use?

> "Not used today" can become "used tomorrow" — set a review date.

---

## Investigate: secrets — contain first

1. **Rotate / revoke** the credential (assume compromised)
2. Check **validity** — active, inactive, unknown (treat unknown as active)
3. Determine **exposure**: history, forks, issues, logs, public?
4. Review **provider audit logs** for misuse
5. Remove from code, move to a secret store, then **close as Revoked**

> Deleting the line from `main` is **not** remediation — it's still in git history.

---

## Investigation outcomes

| Verdict | Meaning | Action |
|---|---|---|
| **True positive** | Real & reachable | Fix (prioritised) |
| **True positive, low risk** | Real but mitigated / not exposed | Fix if cheap, else risk-accept with approval |
| **Not applicable** | Test code / dev-only / unused path | Dismiss with correct reason |
| **False positive** | Tool is wrong | Tune if systemic, dismiss with evidence if one-off |

---

## Fix → Tune → Dismiss

```text
Can we fix it cheaply?  ── yes ──► FIX (Autofix / Dependabot PR / rotate)
        │ no
Is it a systemic FP/noise? ── yes ──► TUNE (config, query filter, model pack,
        │ no                           auto-triage rule, refactor to a recognised pattern)
Is it a one-off FP / N/A / accepted risk?
        └──────────────► DISMISS with reason + evidence + owner + review date
```

---

## Choose the *true* dismissal reason

| Code scanning | Dependabot | Secret scanning |
|---|---|---|
| False positive | Alert is inaccurate | False positive |
| Used in tests | Vulnerable code not used | Used in tests |
| Won't fix ⚠️ | Risk is tolerable ⚠️ | Won't fix ⚠️ |
| | No bandwidth to fix ⚠️ | Revoked ✅ |
| | Fix already started | |

⚠️ = **risk acceptance**, not a false positive → needs approver + review date

---

## The dismissal comment standard

```text
[TAG] evidence | control | approver | review-by | ticket
```

✅ `[FP] name validated by assertSafeFileName() /^[a-z0-9-]+\.pdf$/ before sendFile; unit test files.test.js | approver @sec-lead | review 2027-05 | SEC-142`

❌ `not an issue` · `fp` · `dev only` · *(blank)*

> Write it for the auditor who reads it in 12 months.

---

## Governing dismissals

- **Delegated alert dismissal** (code & secret scanning): developers *request*, security reviewers *approve*
- **Delegated bypass** for push protection — no silent secret pushes
- **Audit**: audit log + REST API + webhooks record who/when/why
- **Periodic review** (e.g., quarterly) of dismissed alerts:
  - weak/blank justification · risk acceptance past review date
  - secret dismissed but still **active** · "used in tests" outside test paths
- **Reopen** when context changes

---

## Manage at scale

- **Ownership**: CODEOWNERS, teams, custom properties (tier, exposure)
- **Security overview**: by team / property / severity; coverage & trend
- **Security campaigns**: burn down a theme (e.g., SQLi in tier-1) with due dates
- **Copilot Autofix / assign to Copilot**: fix suggestions & PRs for backlog alerts — humans still review
- **Rulesets**: block merges on new High+ alerts

---

## Metrics that matter

| Measure | Why |
|---|---|
| MTTR by tier | Are SLAs met? |
| % resolved by **fix** vs **dismiss** | Are we reducing risk or hiding it? |
| Dismissals by reason / by team | Spot FP hotspots (tune!) and over-dismissal |
| Alerts fixed **in PR** vs reaching default branch | Is the gate working? |
| SLA breaches & risk acceptances past review | Governance health |

---

## Roles (RACI-lite)

| Activity | Developer | Tech lead / champion | Security |
|---|---|---|---|
| Triage new PR alerts | **R** | A | C |
| Backlog prioritisation | C | **R/A** | C |
| False positive dismissal | R (request) | C | **A** (approve) |
| Risk acceptance | C | R | **A** |
| Tuning (config/models/rules) | C | R | **A** |
| Dismissal audit | I | C | **R/A** |

---

<!-- _class: lead -->
# Hands-on demo (10 min)
`demo-app/` — an intentionally vulnerable Node.js app

1. Prioritise the backlog · 2. Investigate & fix a true positive
3. Handle a false positive · 4. Triage dependencies & a secret
5. Audit dismissed findings

---

## Takeaways

1. **Prioritise by risk, not by count** — severity × exploitability × exposure × criticality
2. **Prove before you dismiss** — follow the path, check reachability, rotate secrets first
3. **Fix → Tune → Dismiss** — and pick the *true* reason
4. **Every dismissal has an owner and an expiry** — audit and reopen

📄 Handout: `sessions/01-alert-triage/03-triage-playbook.md` · 🧪 Practice: `demo-app/` + `tools/`

➡️ Next: **Session 2** — remediating with GitHub Copilot · **Session 3** — security campaigns
