# Hands-on exercise — plan, monitor and govern a security campaign

**Time:** 15 min (groups of 3–4), or self-paced.
**Use:** the [campaign playbook](03-campaign-playbook.md) canvas and checklists.

## Scenario
ACME Retail has **60 repositories**. Repository custom properties: `tier` (1–3) and `exposure` (`internet` / `internal`).
Open code scanning alerts on default branches (after Session 1 triage removed known false positives):

| Class (CWE) | Tier-1 internet | Tier-1 internal | Tier-2/3 | Autofix supported |
|---|---|---|---|---|
| SQL injection (CWE-89) | 38 alerts / 9 repos | 12 / 4 | 140 / 31 | ~95 % |
| Command injection (CWE-78) | 6 / 3 | 2 / 2 | 25 / 12 | ~80 % |
| Reflected XSS (CWE-79) | 54 / 11 | 0 | 310 / 40 | ~90 % |
| Missing rate limiting (CWE-770) | 70 / 14 | 30 / 8 | 600 / 52 | low |
| Hard-coded credentials (CWE-798) | 9 / 6 | 4 / 3 | 61 / 25 | partial |

Also: **14 active secret scanning alerts** across 8 repos. The 14 tier-1 teams can absorb about **12 fixes per week in total**
alongside feature work. A **release freeze** starts in 6 weeks and lasts 2 weeks.

## Part A — Design the first campaign (7 min)
Fill in the campaign canvas: **theme, scope filter, alerts/repos in scope, objective, due date (show the maths), managers,
contact link, tracking issues (y/n), Copilot approach**. Also decide what happens to the **secret alerts** and the **CWE-770** alerts.

## Part B — Monitor (4 min)
Three weeks after launch, `tools/campaign.ps1` shows:

| # | Campaign | Due in | Open | In progress | Closed | Closed % | Time % | Flags |
|---|---|---|---|---|---|---|---|---|
| 1 | Injection in tier-1 internet apps | 2 wks | 20 | 6 | 18 | 41 | 60 | |
| 2 | Hard-coded credentials | 3 wks | 0 | 0 | 13 | 100 | 50 | |
| 3 | XSS tier-1 | 1 wk | 54 | 0 | 0 | 0 | 85 | NOT-STARTED NO-CONTACT-LINK |

For each, state the **status** (on track / at risk / not started / suspicious) and your **next action**.
Extra fact for #2: 11 of the 13 closed alerts are **dismissed** as *Won't fix* with the comment "moving to vault next quarter".

## Part C — Governance (4 min)
Spot at least **five** governance problems in this proposal from a team lead:

> *"Campaign: **All open alerts** (1,371). Due **in 2 weeks** so we hit the quarterly KPI of 'alerts closed'. I'll create it myself
> (I'm a repo admin). No manager needed — teams can figure it out. Developers can dismiss anything they think is low risk.
> We'll assign the secret alerts to contractors from another org unit to speed things up, and assign everything else to Copilot."*

<details>
<summary><strong>Answer key (facilitator)</strong></summary>

### Part A — a good answer
| Field | Example |
|---|---|
| Theme | **Injection (SQL + command) in tier-1 internet-facing apps** — highest exploitability × exposure × criticality |
| Scope | `is:open tool:CodeQL props.tier:1 props.exposure:internet` + rules for CWE-89/CWE-78 (optionally `autofix:supported`) → **44 alerts / ~10–12 repos** |
| Objective | *≥ 90 % fixed (not dismissed), 0 open command injection, by due date; each team adopts parameterised-query / execFile patterns* |
| Due date | 44 ÷ 12 ≈ 4 weeks + 1 buffer = **5 weeks** → lands **before** the freeze (week 6). Good. |
| Managers / contact | AppSec lead (security manager) + AppSec team; Discussion thread |
| Tracking issues | Yes — 10–12 repos, teams plan from issues |
| Copilot | Autofix for all (~90 % supported); agentic autofix for multi-alert repos within an agreed AI-credit budget; custom instructions with approved patterns |

- **Secrets (14 active)**: **not** a campaign deadline 5 weeks out — they're **P0** under SLA (rotate now). A secret campaign is fine for *tracking*, with rotation evidence required.
- **CWE-770**: mostly low-precision / mitigated at the gateway → **tune / risk-accept centrally** (Session 1), not a developer campaign. Candidate for a later, scoped campaign.
- Next campaigns (after the freeze): XSS tier-1 (54), then SQLi tier-1 internal + tier-2 (split to stay ≤ 1000 and themed).

### Part B
| # | Status | Next action |
|---|---|---|
| 1 | **At risk** (41 % closed vs 60 % time; 6 in progress is a good sign) | Check-in with repos with zero movement; offer pairing / assign-to-Copilot; confirm the date still fits before the freeze. |
| 2 | **Suspicious** — 100 % "closed" but 85 % **dismissed** as *Won't fix* with no approver/review date/rotation | Reopen; credentials need **rotation** and removal; the right status is a dated risk acceptance with approver at best. Report outcome as 2/13 fixed. |
| 3 | **Not started**, 1 week left, no contact link | Escalate to eng leads; add contact link; decide: extend with reason or close and relaunch after the freeze with a realistic date. Check whether notifications/issues reached the teams. |

### Part C — governance problems
1. **"All open alerts"** — no theme, exceeds the **1000-alert limit**, mixes P0 secrets with noise.
2. **2-week due date** with no capacity basis (1,371 ÷ ~12/week ≈ 2+ years for tier-1 capacity).
3. **KPI = "alerts closed"** incentivises dismissals; measure **fixed** and risk reduced.
4. **Repo admin can't create** campaigns — requires **org owner / security manager**; and a campaign **must have managers**.
5. **"Dismiss anything low risk"** — violates the dismissal standard; use **delegated dismissal** with evidence, approver, review date.
6. **Assigning secret alerts to people outside the team** — assignment can **temporarily raise permissions**; least privilege, and secrets need **rotation** by owners.
7. **"Everything to Copilot"** — agentic autofix limited to 25 alerts per session, consumes **AI credits + Actions minutes** (budget), can't validate `security-extended`/third-party alerts, and PRs still need **human review**.
8. No contact link, no guidance, no pre-triage of false positives, no close-out/retro plan.
</details>
