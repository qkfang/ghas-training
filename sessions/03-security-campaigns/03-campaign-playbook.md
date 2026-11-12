# Security Campaign Playbook (handout)

A reference for planning, running, monitoring and governing GHAS security campaigns.
Thresholds and durations are **examples** — align them with your vulnerability management policy.

---

## 1. Campaign canvas (fill in before you create anything)

| Field | Your campaign |
|---|---|
| **Theme** (one vulnerability class / secret type) | e.g. *Injection (SQL, command) in tier-1 apps* |
| **Why it matters** (risk statement) | e.g. *Internet-facing, customer data; injection is our top exploited class* |
| **Scope filter / template** | e.g. `is:open tool:CodeQL rule:js/sql-injection,js/command-line-injection props.tier:1` |
| **Alerts / repos in scope** | ≤ 1000 alerts · N repos |
| **Pre-triage done?** | FP hotspots tuned or dismissed (Session 1) · vendored code excluded |
| **Objective** (measurable) | e.g. *≥ 90 % fixed (not dismissed) and 0 open critical by 28 Feb* |
| **Capacity → due date** | alerts ÷ fixes/week + 1 week buffer |
| **Campaign manager(s)** | owner / security manager (or team with that role) |
| **Contact link** | Discussion / channel |
| **Tracking issues?** | Yes / No (code campaigns only) |
| **Guidance links** | secure pattern page · Copilot custom instructions · OWASP |
| **Copilot** | Autofix (default) · agentic autofix budget (AI credits + Actions minutes) |
| **Check-in cadence** | weekly · escalation path |
| **Close-out owner** | who reports outcome to risk owners |

## 2. Scoping rules

- **One theme** per campaign. Several focused campaigns > one giant one.
- **≤ 1000 alerts** (hard limit). Narrow by repository, severity, language or custom property.
- Use **repository custom properties** (`tier`, `exposure`, `data-class`) for criticality instead of hand-picking repos.
- Prefer `autofix:supported` alerts for early campaigns — quick wins build momentum.
- **Pre-triage**: remove known false positives and noise first; don't make developers rediscover them.
- Check **repo count**: avoid issuing a tracking issue to 200 repos for 1 alert each — handle long tails separately.
- **P0s don't wait** for a campaign — handle them under SLA (Session 1). Campaigns burn down P1–P3.
- Code campaigns include **default-branch** alerts only.

## 3. Objectives & timeframes

**Objective template:** *Reduce <risk> in <scope> by <fixing ≥ X % / 0 open critical> by <date>, and <capability outcome>.*

**Timeframe:** `weeks ≈ ceil(alerts ÷ team fixes per week) + 1` (use `tools/campaign.ps1 -Plan -WeeklyCapacity N`).
Avoid release freezes and holidays. Prefer **4–8 weeks**. Re-baseline openly if scope changes — don't silently slip.

## 4. Launch checklist

- [ ] Canvas complete and agreed with engineering leads
- [ ] Scope selected (filter or template), ≤ 1000 alerts
- [ ] Description: objective, why, guidance links (it is copied into tracking issues)
- [ ] Due date, manager(s), contact link set
- [ ] *Generate issues* decided
- [ ] Saved as **draft** → reviewed → **published**
- [ ] Kick-off message to teams; managers available for PR reviews

## 5. Monitoring

| Status | Meaning |
|---|---|
| Open | Not addressed |
| In progress | Branch / PR created from the campaign or alert (code only) |
| Fixed | Resolved, inside or outside the campaign |
| Dismissed | Reviewed and intentionally not fixed |

**Weekly check-in** (`tools/campaign.ps1 -Org <org>`):

| Signal | Example threshold | Action |
|---|---|---|
| **AT-RISK** | closed % more than 15 pts behind time elapsed % | Contact repos with no movement; offer pairing / Copilot |
| **NOT-STARTED** | ≥ 25 % of time gone, nothing closed or in progress | Escalate to eng lead; check notifications/issues reached the team |
| **OVERDUE** | past due date with open alerts | Close out: extend with reason, roll over, or formally risk-accept |
| High dismiss share | > 20 % of closed alerts dismissed | Audit dismissals (`tools/alert-report.ps1 -DismissedOnly`) |

**Outcome metrics** (report at close): % fixed vs dismissed · open critical/high in scope · time to first PR per repo · MTTR vs non-campaign · recurrence of the class after 90 days · Autofix suggestions used/accepted.

## 6. Governance checklist

- [ ] Campaign maps to a **policy** requirement / SLA and a named **risk owner**.
- [ ] Created by an **org owner / security manager**; managers hold the required role.
- [ ] Dismissals follow the **Session 1 comment standard**; delegated dismissal on for code & secret scanning.
- [ ] Secret campaigns: **rotation evidence** required before closing as *Revoked*; assignments reviewed (may raise permissions temporarily).
- [ ] Agentic autofix **budget** agreed (AI credits + Actions minutes).
- [ ] Every fix PR goes through normal review + CodeQL check (rulesets).
- [ ] **Evidence** retained: campaign scope/objective/dates, API export at launch and close, tracking issues, audit log.
- [ ] **Close** on the due date; outcome vs objective reported; retro actions owned.
- [ ] **Prevent recurrence**: rulesets (merge protection), PR Autofix, custom instructions, training.

## 7. Anti-patterns

"Fix everything" campaigns · due dates without capacity · no contact/absent manager · success measured as *closed* · repeated themes every quarter with no gate · secret campaigns closed without rotation · campaigns left open indefinitely.

## 8. Useful API calls

```bash
# Org-wide scope check (open code scanning alerts) — narrow with jq
gh api "orgs/ORG/code-scanning/alerts?state=open&per_page=100" --paginate \
  --jq '.[] | [.repository.full_name, .number, .rule.id, .rule.security_severity_level] | @tsv'
# Create a published campaign (single user manager; team_managers also supported)
gh api -X POST orgs/ORG/campaigns --input campaign.json
#   {"name":"…","description":"…","ends_at":"2027-02-28T23:59:59Z","managers":["sec-lead"],
#    "contact_link":"https://…","generate_issues":true,
#    "code_scanning_alerts":[{"repository_id":123,"alert_numbers":[1,2]}]}
# Progress
gh api "orgs/ORG/campaigns?state=open" --jq '.[] | [.number, .name, .ends_at, .alert_stats.open_count, .alert_stats.in_progress_count, .alert_stats.closed_count] | @tsv'
# Close
gh api -X PATCH orgs/ORG/campaigns/NUMBER -f state=closed
```

Or use [`tools/campaign.ps1`](../../tools/campaign.ps1) (`-Plan`, `-Create`, default progress report).

## References
- [About security campaigns](https://docs.github.com/en/code-security/concepts/security-at-scale/about-security-campaigns)
- [Running a security campaign to fix alerts at scale](https://docs.github.com/en/code-security/tutorials/secure-your-organization/best-practice-fix-alerts-at-scale)
- [Creating and managing security campaigns](https://docs.github.com/en/code-security/how-tos/manage-security-alerts/remediate-alerts-at-scale/creating-managing-security-campaigns)
- [Tracking security campaigns](https://docs.github.com/en/code-security/how-tos/manage-security-alerts/remediate-alerts-at-scale/tracking-security-campaigns)
- [REST API: security campaigns](https://docs.github.com/en/rest/campaigns/campaigns)
