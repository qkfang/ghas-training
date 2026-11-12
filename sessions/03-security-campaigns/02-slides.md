---
marp: true
theme: default
paginate: true
title: GHAS security campaigns for security and risk
---

<!-- _class: lead -->
# GHAS Security Campaigns for Security and Risk
### Session 3 · Organise, scope, monitor and govern remediation at scale

45 min · 35 min talk + 10 min hands-on demo

---

## Outcome for today

You will be able to:

1. Use **security campaigns** to organise remediation work across teams
2. Set a campaign's **scope, objectives and timeframe** deliberately
3. **Monitor** progress and measure **outcomes**, not activity
4. Apply **governance** so campaigns reduce risk — and stand up to audit

---

## Where we are in the series

| Session | Question it answers |
|---|---|
| 1 · Triage | *Which* alerts matter, and is each one real? |
| 2 · Copilot remediation | *How* do we fix one quickly and safely? |
| **3 · Campaigns** | How do we get **hundreds** fixed, across **teams**, by a **date**? |

> The backlog doesn't shrink by itself — it needs a plan, an owner and a deadline.

---

## What is a security campaign?

A **named, time-boxed set of alerts** that security asks developers to fix, with:

- a **scope** (selected alerts across many repositories — up to **1000**)
- a **due date** and a **short description** of the goal
- one or more **campaign managers** + a **contact link**
- developer **notifications**, optional **tracking issues** per repository
- **Copilot Autofix** suggested automatically for code alerts
- a **tracking view** for progress

Created by **org owners / security managers** — UI or REST API.

---

## Why campaigns, not spreadsheets & tickets?

| Spreadsheet / ticket blast | Security campaign |
|---|---|
| Copy of alert data, instantly stale | Live alert state — fixed alerts drop off automatically |
| Developers leave their workflow | Alerts, Autofix and issues **in the repo** |
| No clear contact | Named **manager** + contact link |
| Progress = manual chasing | Built-in **tracking**: open / in progress / fixed / dismissed |
| One-off push | Repeatable, themed **series** |

---

## Code vs secret campaigns

| | Code scanning | Secret scanning *(public preview)* |
|---|---|---|
| Alerts | Default branch only | Secret alerts |
| Tracking issues per repo | ✅ | ❌ |
| Notified developers | Write access to repo | Can view alert list |
| Assign alerts | ✅ users (and Copilot, if agentic autofix enabled) | ✅ users — **may raise permissions** temporarily |
| Automatic remediation | **Copilot Autofix** | ❌ — rotate & revoke |
| "In progress" status | ✅ | ❌ |

---

## The developer experience

- Notification → **Security → Campaigns** in their repo
- Campaign alerts listed with due date, manager and contact link
- **Copilot Autofix** ready on code alerts → *Create PR with fix* (Session 2)
- Assign alerts to themselves, a teammate, or **Copilot** (≤ 25 alerts per agent session → one draft PR)
- Tracking **issue** fits team boards and sprint planning

> Make the right thing the easy thing: one place, one deadline, a fix already suggested.

---

## Organising the work

- **Theme** campaigns by vulnerability class (e.g. *Cross-site scripting (CWE-79)*, injection, exposed secrets)
- **One theme at a time** builds skill: fix one → recognise the next
- Run several **focused** campaigns rather than one "fix everything"
- **Prepare** before launch: guidance page, secure patterns, Copilot custom instructions
- Line up **managers** who can review PRs and answer questions

---

## Setting scope

Start in **Security overview → alerts**, or a **campaign template**:

```text
is:open tool:CodeQL severity:critical,high      # or a template, e.g. Cross-site scripting (CWE-79)
props.tier:1 props.exposure:internet            # repo custom properties = asset criticality
autofix:supported                               # alerts Copilot Autofix can help with
```

- **≤ 1000 alerts** per campaign — narrow by repo, severity, language, property
- Exclude what Session 1 says to **tune/dismiss** first (FP hotspots, vendored code)
- Check **repo count**: 1 tracking issue each — don't flood 200 teams with 1 alert apiece

---

## Setting objectives

Make the objective **specific and measurable** — and about **risk**:

| Weak | Strong |
|---|---|
| "Fix security alerts" | "Remove all **SQL/command injection** from **tier-1, internet-facing** apps" |
| "Reduce backlog" | "**≥ 90 % fixed** (not dismissed) of 140 alerts by **28 Feb**; **0 open critical**" |
| "Raise awareness" | "Every team in scope merges **≥ 1** fix and adopts the secure-query pattern" |

Put the objective, *why it matters* and **guidance links** in the campaign description.

---

## Setting timeframes

```text
weeks ≈ ceil( alerts in scope ÷ fixes per week the teams can absorb ) + 1 week buffer
```

- Capacity is **alongside feature work** — be realistic
- Avoid holidays, release freezes, quarter-end
- Align with **SLAs**: a P0 never waits for a campaign; campaigns burn down **P1–P3**
- Prefer **4–8 week** themed campaigns over open-ended ones
- `tools/campaign.ps1 -Plan -WeeklyCapacity N` suggests an end date

---

## Launch checklist

1. Scope selected (filter / template), **≤ 1000** alerts, FPs pre-triaged
2. Name + **short description** with objective & guidance links
3. **Due date** from capacity
4. **Managers** (org owner / security manager, or a team with that role) + **contact link**
5. **Generate issues**? (code campaigns) — yes if teams plan from issues
6. Save as **draft** → review with engineering leads → **publish**

> Drafts are UI-only; the REST API sees published campaigns.

---

## Monitoring progress

**Org view** (Security and quality → Campaigns): open/closed campaigns, alerts by status

| Status | Meaning |
|---|---|
| **Open** | Not addressed yet |
| **In progress** | Branch / PR created from the campaign or alert (code only) |
| **Fixed** | Resolved — inside or outside the campaign |
| **Dismissed** | Reviewed and intentionally not fixed |

**Single campaign view**: progress, status vs due date, **Copilot Autofix** availability, by-repo drill-down

---

## Burn-down vs time

```text
Closed %  ────────────────────────────►  compare with  ◄──  Time elapsed %
   42 %   ON-TRACK     (time 33 %)
   10 %   AT-RISK      (time 80 %)   → follow up with repo owners / adjust scope
    0 %   NOT-STARTED  (time 50 %)   → nobody has opened a branch — escalate
   90 %   OVERDUE      (past due)    → close out the tail or extend with reason
```

- Weekly check-in; **repositories with no movement** first
- Use the API (`alert_stats`) for dashboards: `tools/campaign.ps1 -Org <org>`

---

## Measuring outcomes, not activity

| Measure | Why |
|---|---|
| **% fixed vs dismissed** | A campaign closed by dismissals moved risk, not removed it |
| Open **critical/high** in scope at close | The risk objective |
| Time to first PR per repo | Engagement |
| MTTR during vs outside campaigns | Is the format working? |
| **Recurrence** of the class 90 days later | Did teams learn the pattern? (rulesets + PR Autofix keep it out) |
| Autofix used / accepted | Copilot leverage |

---

## Governance considerations

- **Policy alignment**: campaigns implement the vulnerability-management **policy** & SLAs — they don't replace them
- **Roles**: only org owners / security managers create; managers accountable for support & review
- **Dismissals inside campaigns** follow the Session 1 standard (reason + evidence + approver + review date); use **delegated dismissal**
- **Access**: assigning secret alerts can **temporarily raise permissions** — assign deliberately
- **Cost**: agentic autofix consumes **AI credits + Actions minutes** — budget it
- **Evidence**: campaign record + API exports + audit log = audit trail

---

## Governance: RACI-lite

| Activity | Security (campaign owner) | Campaign manager | Eng lead | Developer |
|---|---|---|---|---|
| Choose theme & scope | **A/R** | C | C | I |
| Objective & due date | **A** | R | C | I |
| Fix alerts | I | C (review) | A | **R** |
| Dismiss / risk-accept | **A** (approve) | C | R | R (request) |
| Track & escalate | A | **R** | C | I |
| Close & report outcome | **A/R** | R | I | I |

---

## Closing a campaign

- Close at the due date — **don't** let it run forever
- Remaining open alerts: **extend** with reason, roll into the **next** campaign, or risk-accept **formally**
- Audit **dismissals** made during the campaign (`tools/alert-report.ps1 -DismissedOnly`)
- Report **outcome vs objective** to risk owners
- **Retro**: what made fixes slow? → tuning, custom instructions, training, rulesets to stop recurrence

---

## Anti-patterns

- 🚩 "All open alerts" campaign — 1000 alerts, no theme, no chance
- 🚩 Due date picked without capacity → teams give up
- 🚩 No contact link / absent manager → questions go nowhere
- 🚩 Success = "alerts closed" → mass dismissals
- 🚩 Same class returns next quarter → no gate (rulesets, PR Autofix)
- 🚩 Secret campaign with no **rotation** evidence

---

<!-- _class: lead -->
# Hands-on demo (10 min)
Org with `ghas-training` (+ optional second repo)

1. Scope & objective from Security overview · 2. Create (draft → publish)
3. Developer view: issue, Autofix, assign to Copilot · 4. Monitor progress
5. Governance: dismissal audit & close-out

---

## Takeaways

1. **Campaigns turn backlog into a plan** — themed, owned, dated, in the developer's workflow
2. **Scope deliberately** — ≤ 1000 alerts, a single theme, criticality via custom properties
3. **Objectives about risk**, timeframes from **capacity**
4. **Monitor burn-down vs time**; judge by **fixed**, not closed
5. **Govern**: policy-aligned, dismissals evidenced, access & cost managed, outcome reported

📄 Handout: `sessions/03-security-campaigns/03-campaign-playbook.md` · 🧪 Practice: `tools/campaign.ps1`
