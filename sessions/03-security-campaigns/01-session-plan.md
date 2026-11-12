# Session 3 plan — GHAS security campaigns for security and risk

| | |
|---|---|
| **Duration** | 45 minutes (35 min content + 10 min hands-on demo) |
| **Audience** | Security leads, AppSec champions, engineering managers, risk/compliance stakeholders, tech leads |
| **Outcome** | Attendees can use security campaigns to **organise** remediation, set **scope, objectives and timeframes**, **monitor** progress and outcomes, and apply **governance** so campaigns measurably reduce risk. |
| **Prereqs** | [Session 1](../01-alert-triage/01-session-plan.md) (triage & dismissals) and [Session 2](../02-copilot-remediation/01-session-plan.md) (Copilot remediation) recommended. |
| **Materials** | [`02-slides.md`](02-slides.md) (Marp) · [`03-campaign-playbook.md`](03-campaign-playbook.md) (handout) · [`04-demo-script.md`](04-demo-script.md) · [`05-hands-on-exercise.md`](05-hands-on-exercise.md) · [`../../tools/campaign.ps1`](../../tools/campaign.ps1) · [`../../tools/alert-report.ps1`](../../tools/alert-report.ps1) |
| **Requires** | An **organization** (campaigns are not available on personal accounts) with GitHub Code Security (code campaigns) / Secret Protection (secret campaigns), and the presenter as **org owner or security manager**. |

## Learning objectives

By the end, attendees can:

1. Explain what a security campaign is, how code and secret campaigns differ, and why campaigns beat spreadsheets/ticket blasts.
2. Select a campaign **scope** (filters, templates, custom properties, `autofix:supported`, ≤ 1000 alerts) that a set of teams can realistically finish.
3. Write a measurable, risk-based **objective** and derive a **timeframe** from team capacity.
4. **Monitor** a campaign (open / in progress / fixed / dismissed, burn-down vs time) and judge **outcomes** by fixes, not closures.
5. Apply **governance**: policy/SLA alignment, roles, dismissal standards, access and cost, evidence, close-out and retro.

## Run sheet

| Time | Min | Section | Slides | Key message |
|---|---|---|---|---|
| 0:00 | 3 | Welcome, series recap, outcome | 1–3 | The backlog needs a plan, an owner and a deadline. |
| 0:03 | 7 | **Use security campaigns to organise remediation work** | 4–8 | Themed, owned, dated work inside the developer's workflow. |
| 0:10 | 8 | **Setting campaign scope, objectives and timeframes** | 9–12 | Focused scope, risk-based objective, capacity-based date. |
| 0:18 | 7 | **Monitoring remediation progress and outcomes** | 13–15 | Burn-down vs time; judge by *fixed*, not *closed*. |
| 0:25 | 8 | **Governance considerations** | 16–19 | Campaigns implement policy — with evidence. |
| 0:33 | 10 | **Hands-on demo** (demo org) | 20 | Plan → launch → work → monitor → close. |
| 0:43 | 2 | Close: takeaways & handout | 21 | Use the playbook's campaign canvas. |

> Timing tip: if running late, skip slide 19 (anti-patterns) — they're in the handout — and Segment 3 step 3 of the demo.

## Speaker notes by section

### 1. Welcome & recap (3 min)
- Series arc: Session 1 decides *which* alerts matter, Session 2 makes fixing one *cheap*, Session 3 gets *many* fixed across teams by a date.
- Poll: "Who has sent a spreadsheet of vulnerabilities to engineering teams? How did that go?"

### 2. Organising remediation with campaigns (7 min)
- Definition (slide 4): named, time-boxed set of alerts; up to **1000**; managers + contact link; notifications; optional tracking issues; Autofix on code alerts; tracking view. Created by **org owners / security managers** via UI or REST API.
- Why not spreadsheets (slide 5): live state, in-workflow, named contact, built-in tracking, repeatable.
- Code vs secret campaigns (slide 6): secret campaigns are **public preview**; no tracking issues, no in-progress state, no Autofix; assigning a secret alert can **temporarily raise** the assignee's permissions; code campaigns only include **default-branch** alerts.
- Developer experience (slide 7): repo **Security → Campaigns**, Autofix ready, assign to self/teammate/**Copilot** (agentic autofix: up to 25 alerts per session → one draft PR).
- Organising principles (slide 8): theme by vulnerability class, one theme at a time, several focused campaigns, prepare guidance & custom instructions, line up managers.

### 3. Scope, objectives, timeframes (8 min)
- Scope (slide 9): Security overview filters or templates (e.g. *Cross-site scripting (CWE-79)*); use **repository custom properties** (`tier`, `exposure`) so criticality is encoded once; `autofix:supported` to lower effort; ≤ 1000 alerts; pre-triage false positives (Session 1) so developers aren't sent noise; watch the **repo count** (issues per repo).
- Objectives (slide 10): specific, measurable, risk-framed. Include *why it matters* and guidance links in the description.
- Timeframes (slide 11): capacity formula; avoid freezes/holidays; **P0s never wait for a campaign** — campaigns burn down P1–P3; prefer 4–8 week campaigns. Show `tools/campaign.ps1 -Plan -WeeklyCapacity`.
- Launch checklist (slide 12): draft → review with engineering leads → publish. API only sees **published** campaigns.

### 4. Monitoring progress & outcomes (7 min)
- Statuses (slide 13): Open, In progress (code only: branch/PR created from the campaign/alert), Fixed (inside or outside the campaign), Dismissed.
- Single-campaign view: progress, status vs due date, Copilot Autofix availability, by-repo drill-down, group-by none for all alerts.
- Burn-down vs time (slide 14): ON-TRACK / AT-RISK / NOT-STARTED / OVERDUE; weekly cadence; chase repos with no movement first. `tools/campaign.ps1` reproduces this from the API's `alert_stats`.
- Outcomes (slide 15): **% fixed vs dismissed** (the API's `closed_count` includes dismissals — audit them), open critical/high at close, time to first PR, MTTR, **recurrence** after 90 days, Autofix use.

### 5. Governance (8 min)
- Campaigns **implement** the vulnerability-management policy and SLAs; they don't replace them.
- Roles & RACI (slide 17). Only owners/security managers create; managers must be owners/security managers or a team with that role.
- Dismissals inside campaigns follow the **Session 1 standard** and **delegated dismissal** — otherwise "campaign complete" can mean "risk hidden".
- Access: secret-alert assignment may temporarily elevate permissions → assign deliberately, prefer owners of the repo.
- Cost: agentic autofix consumes AI credits + Actions minutes → budget per campaign.
- Evidence: campaign record (scope, objective, dates, managers), API exports, tracking issues, audit log.
- Close-out (slide 18): close on the due date; extend with reason / roll over / formally risk-accept; audit dismissals; report outcome vs objective; retro → tuning, instructions, rulesets to prevent recurrence.

### 6. Demo (10 min) — see [`04-demo-script.md`](04-demo-script.md)

### 7. Close (2 min)
- Takeaways (slide 21). Hand out the **campaign canvas** in the playbook — fill one in for your next campaign.

## Pre-session checklist (T-2 days — org setup takes longer)
- [ ] Demo **organization** available with GHAS (Code Security; Secret Protection for secret campaigns) and you as owner/security manager.
- [ ] `ghas-training` forked/transferred into the org; Session 1 setup run there (`tools/enable-ghas.ps1`, CodeQL workflow) so alerts exist.
- [ ] Org custom property `tier` created and set to `1` on the demo repo (Settings → Custom properties).
- [ ] *Optional:* a second repo with alerts for multi-repo flavour; agentic autofix enabled for the org.
- [ ] A **pre-created campaign** published a few days earlier (so the tracking view has history) — e.g. via `tools/campaign.ps1 -Create`.
- [ ] A GitHub Discussion (or Teams/Slack channel) to use as the **contact link**.
- [ ] Screenshots of each demo step as fallback.
