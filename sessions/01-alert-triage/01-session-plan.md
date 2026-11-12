# Session plan — Prioritising, investigating & managing GHAS alerts

| | |
|---|---|
| **Duration** | 45 minutes (35 min content + 10 min hands-on demo) |
| **Audience** | Developers, tech leads, AppSec champions, security engineers |
| **Outcome** | Attendees understand how GHAS alerts should be **assessed** (prioritised & investigated) and **managed** (fixed, tuned, dismissed, audited) — including false positives and dismissed findings. |
| **Prereqs** | Basic familiarity with GitHub repos/PRs. No GHAS admin rights needed to follow. |
| **Materials** | [`02-slides.md`](02-slides.md) (Marp) · [`03-triage-playbook.md`](03-triage-playbook.md) (handout) · [`04-demo-script.md`](04-demo-script.md) · [`05-hands-on-exercise.md`](05-hands-on-exercise.md) · [`../demo-app`](../demo-app) · [`../tools`](../tools) |

## Learning objectives

By the end, attendees can:

1. Explain the three GHAS alert sources (code scanning, Dependabot, secret scanning) and what "severity" means for each.
2. Prioritise alerts using **severity × exploitability × exposure × asset criticality** — not severity alone.
3. Investigate an alert to decide **true positive / false positive / not applicable**.
4. Pick the correct resolution path: **Fix → Tune → Dismiss (with evidence)**, and the right dismissal reason.
5. Govern dismissed findings: justification standard, approvals (delegated dismissal), periodic audit and reopening.

## Run sheet

| Time | Min | Section | Slides | Key message |
|---|---|---|---|---|
| 0:00 | 3 | Welcome, outcome, the "alert fatigue" problem | 1–3 | Goal is *risk reduced*, not *alerts closed*. |
| 0:03 | 5 | The alert landscape | 4–6 | Three sources, different signals, different lifecycles (secrets never auto-close). |
| 0:08 | 9 | **Prioritise** — the risk model & signals | 7–11 | Severity is an input, not the answer. New-in-PR ≠ backlog. |
| 0:17 | 8 | **Investigate** — per alert type | 12–15 | Prove reachability/exploitability; secrets: rotate first, investigate second. |
| 0:25 | 7 | **False positives & dismissals** | 16–19 | Fix > Tune > Dismiss. Every dismissal is a risk decision with an owner. |
| 0:32 | 3 | **Manage at scale** — governance, campaigns, metrics | 20–22 | Ownership, SLAs, audits, campaigns, Autofix. |
| 0:35 | 10 | **Hands-on demo** (`demo-app`) | 23 | See it end-to-end on real alerts. |
| 0:45 | — | Close: takeaways & handout | 24 | Use the playbook. |

> Timing tip: if running late, compress "Manage at scale" to 1 minute — the demo covers the audit piece.

## Speaker notes by section

### 1. Welcome & problem (3 min)
- Poll: "Who has a repo with >50 open security alerts?" Most hands go up.
- Alert fatigue causes two failure modes: **ignore everything** or **dismiss everything**. Both leave real risk.
- Frame outcome: a repeatable, defensible process — *what to look at first, how to decide, how to record the decision.*

### 2. Alert landscape (5 min)
- **Code scanning (CodeQL / 3rd-party SARIF)** — flaws in *your* code. Security severity (Critical/High/Medium/Low) is derived from CVSS of CVEs mapped to the rule's CWE. Non-security rules use Error/Warning/Note.
- **Dependabot** — known vulns (GitHub Advisory Database) in dependencies. Signals: CVSS severity, **EPSS** (probability of exploitation in next 30 days), **scope** (runtime vs development), patch availability, direct vs transitive.
- **Secret scanning** — credentials in code/history/issues. Signals: **validity** (active/inactive/unknown) for supported partner patterns, provider, push-protection bypass.
- Lifecycle differences: code scanning alerts auto-**fix** when the analysis no longer finds them; Dependabot alerts auto-close when the dependency is upgraded; **secret scanning alerts never auto-close** — removing the string doesn't revoke it.
- Where to look: repo **Security and quality** tab; org **Security overview**; PR checks/annotations.

### 3. Prioritise (9 min)
- Risk model: **Severity × Exploitability × Exposure × Asset criticality**.
  - Exploitability: data-flow from untrusted source? EPSS? CISA KEV? Public exploit?
  - Exposure: internet-facing? production? runtime vs dev/test? (production-context / linked-artifact filters where enabled; otherwise custom properties such as `exposure=internet`, `tier=1`.)
  - Criticality: data sensitivity, business impact (use repository **custom properties** to encode this once).
- Two streams with different rules:
  - **New alerts in PRs** → *gate*: block merge via rulesets (code scanning merge protection, push protection). Cheapest time to fix; Copilot Autofix suggests the fix inline.
  - **Backlog** → *burn down* by priority, SLA, and security campaigns.
- Priority tiers & example SLAs (adapt to policy): P0 ≤ 24–72h, P1 ≤ 7–14d, P2 ≤ 30–60d, P3 ≤ 90d / campaign. See playbook.
- Secrets are almost always P0 until proven inactive.
- Reduce noise **before** humans see it: Dependabot auto-triage presets (dismiss low-impact dev-scoped npm alerts), custom auto-triage rules, CodeQL `paths-ignore` for vendored/generated code, "only alerts in application code" filter.

### 4. Investigate (8 min)
- **Code scanning**: read the rule help → follow **Show paths** (source → steps → sink) → ask: is the source really untrusted? is there a sanitizer/validation CodeQL can't see? is the sink reachable in prod? Check other branches/PR history. Use Copilot Autofix explanation as a second opinion, not proof.
- **Dependabot**: is the *vulnerable function/feature* used? Is the package runtime or dev? Direct or transitive (dependency graph shows the path)? Is a patched version available, and is the upgrade breaking (semver-major)? EPSS percentile?
- **Secrets**: **contain first** — rotate/revoke, then investigate. Check validity, where it was exposed (history, forks, issues), provider audit logs for misuse. Removing from HEAD is *not* remediation.
- Record findings on the alert (comment / linked issue) so the next person doesn't repeat the work.

### 5. False positives & dismissals (7 min)
- Hierarchy: **Fix** (even if low risk, if cheap) → **Tune** (systemic FP: config, query filters, model packs, auto-triage rules, refactor to a pattern the tool recognises) → **Dismiss** (one-off, with evidence).
- Dismissal reasons — choose the *true* one (they feed reporting):
  - Code scanning: *False positive* · *Used in tests* · *Won't fix*
  - Dependabot: *Fix already started* · *No bandwidth to fix* · *Risk is tolerable* · *Alert is inaccurate* · *Vulnerable code not used*
  - Secret scanning: *Revoked* · *False positive* · *Used in tests* · *Won't fix*
- "No bandwidth" and "Won't fix" are **risk acceptances**, not FPs — require an approver and review date.
- Comment standard (≤280 chars): `[TAG] evidence | control | approver | review date | ticket`.
- Governance: **delegated alert dismissal** (code & secret scanning) — developers *request*, security approves; push-protection **delegated bypass**. Audit log + API for evidence.
- Dismissed ≠ forgotten: quarterly audit, reopen when context changes (code becomes reachable, dependency moves to runtime, secret validity turns active).

### 6. Manage at scale (3 min)
- Ownership: CODEOWNERS / teams, custom properties for tier & exposure.
- Security overview: filter by severity, team, property; track **MTTR**, **% fixed vs dismissed**, **dismissal rate by reason**, **SLA breach count**, **PR-introduced vs fixed in PR**.
- Security campaigns for backlog themes (e.g., "all SQLi in tier-1 apps") with Copilot Autofix and due dates.
- Assign code scanning alerts to Copilot (agentic autofix) for backlog fixes where enabled — still reviewed by humans.

### 7. Demo (10 min) — see [`04-demo-script.md`](04-demo-script.md)

### 8. Close (≤1 min)
- Three takeaways: **Prioritise by risk, not count. Prove before you dismiss. Every dismissal has an owner and an expiry.**
- Point to playbook handout and the demo repo for self-paced practice.

## Pre-session checklist (T-1 day)
- [ ] Run `tools/enable-ghas.ps1`, create the **ACME API key** custom pattern, run the CodeQL workflow.
- [ ] Confirm alerts exist (see expected list in [`../demo-app/README.md`](../demo-app/README.md)).
- [ ] Run `tools/seed-dismissals.ps1` to stage good/bad dismissals for the audit demo.
- [ ] Take **screenshots** of each demo step as a fallback (network/UI changes).
- [ ] Open browser tabs listed in the demo script; zoom 125%+.
