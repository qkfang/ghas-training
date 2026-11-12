# GHAS Alert Triage Playbook (handout)

A one-page reference for assessing and managing GitHub Advanced Security alerts.
SLAs and thresholds are **examples** — align them with your organisation's vulnerability management policy.

---

## 1. Triage flow

```text
            ┌────────────────────────────┐
 New alert ►│ 1. Is it a secret?         │── yes ─► ROTATE/REVOKE now (P0) ─► investigate exposure ─► close "Revoked"
            └─────────────┬──────────────┘
                          │ no
            ┌─────────────▼──────────────┐
            │ 2. Is it real?             │── no ──► Systemic? ─ yes ─► TUNE (config/model/rule) 
            │  (path, sanitiser, usage)  │                     └ no ──► DISMISS "False positive" + evidence
            └─────────────┬──────────────┘
                          │ yes
            ┌─────────────▼──────────────┐
            │ 3. Is it in shipped code?  │── no ──► DISMISS "Used in tests" / auto-triage dev-scope
            │  (runtime, not test/dev)   │
            └─────────────┬──────────────┘
                          │ yes
            ┌─────────────▼──────────────┐
            │ 4. Assign priority P0–P3   │  (section 2)
            └─────────────┬──────────────┘
            ┌─────────────▼──────────────┐
            │ 5. Can it be fixed in SLA? │── yes ─► FIX (Autofix, Dependabot PR, refactor)
            └─────────────┬──────────────┘
                          │ no
                          ▼
             RISK-ACCEPT: "Won't fix" / "Risk is tolerable" + approver + compensating control + review date + ticket
```

## 2. Prioritisation

**Risk = Severity × Exploitability × Exposure × Asset criticality**

| Tier | Criteria (any) | Example SLA |
|---|---|---|
| **P0** | Secret with validity *active* or *unknown* · Critical/High that is reachable **and** internet-facing · Dependency on CISA KEV or high EPSS (e.g. ≥ 10%) in runtime | 24–72 h |
| **P1** | High in production runtime code/dependency · Critical with limited exposure (authenticated/internal) | 7–14 days |
| **P2** | Medium in production · High in non-exposed/internal apps · inactive secret still in history | 30–60 days |
| **P3** | Low/Note · development-scope dependencies · test-only code | 90 days or campaign |

**Adjust up** for: tier-1/regulated apps, sensitive data, public repos, known exploit.
**Adjust down** for: strong compensating control (documented), unreachable code path, archived repo.

**Signals in GHAS**
- Code scanning: security severity, data-flow path ("Show paths"), rule precision, test/generated classification.
- Dependabot: CVSS severity, **EPSS**, `scope:runtime|development`, `has:patch`, direct vs transitive, "Most important" sort.
- Secret scanning: **validity**, provider, location, push-protection bypass reason.
- Context you add: repository **custom properties** (e.g. `tier`, `exposure`, `data-class`), production context / linked artifacts where enabled.

## 3. Investigation checklists

### Code scanning
- [ ] Read rule help & CWE.
- [ ] Follow source → sink path. Is the source attacker-controlled (HTTP input, files, env from users)?
- [ ] Any validation/sanitisation on the path the tool doesn't model (custom validator, framework guard)?
- [ ] Is the code deployed and reachable (route mounted, feature enabled)?
- [ ] Same pattern elsewhere? (fix the class, not the instance)
- [ ] Generate Copilot Autofix; review and test the suggested change.

### Dependabot
- [ ] Runtime or development scope? Direct or transitive (dependency graph path)?
- [ ] Is the vulnerable API/feature used? Is attacker input reaching it?
- [ ] Patched version available? Breaking (semver-major)? Can a grouped security update PR fix it?
- [ ] EPSS / known exploitation?

### Secret scanning
- [ ] **Rotate/revoke first** — assume compromised.
- [ ] Validity check (where supported) — treat *unknown* as active.
- [ ] Exposure: commit history, forks, issues/PRs/wikis, logs, public visibility.
- [ ] Provider audit logs for misuse; incident process if used.
- [ ] Move to a secret store; enable push protection.

## 4. Resolution rules: Fix → Tune → Dismiss

| Situation | Do this | Don't do this |
|---|---|---|
| Real and fixable | Fix (Autofix / Dependabot PR) | Dismiss as "Won't fix" to hit a metric |
| Same false positive appears in many places | **Tune**: CodeQL config/query filters, model packs for custom sanitisers, refactor to a recognised pattern, Dependabot auto-triage rule | Dismiss 40 alerts one at a time |
| Vendored/generated code | `paths-ignore` in CodeQL config | Dismiss as false positive |
| Test fixture / test-only credential | Dismiss **Used in tests** (verify path is test-only) | Dismiss as false positive |
| Real but can't fix now | Risk-accept with approver, control, review date, ticket | Dismiss with blank comment |
| Secret removed from code | **Rotate**, then close as **Revoked** | Close as false positive because "deleted it" |

### Dismissal reasons — pick the true one

| Code scanning | Dependabot (API value) | Secret scanning (API value) |
|---|---|---|
| False positive | This alert is inaccurate or incorrect (`inaccurate`) | False positive (`false_positive`) |
| Used in tests | Vulnerable code is not actually used (`not_used`) | Used in tests (`used_in_tests`) |
| Won't fix ⚠️ | Risk is tolerable to this project (`tolerable_risk`) ⚠️ | Won't fix (`wont_fix`) ⚠️ |
| | No bandwidth to fix this (`no_bandwidth`) ⚠️ | Revoked (`revoked`) |
| | A fix has already been started (`fix_started`) | |

⚠️ = risk acceptance → requires approver + review date.

### Dismissal comment standard (≤ 280 chars)

```text
[FP|TEST|NOT-USED|RISK-ACCEPTED] <evidence> | control: <what mitigates> | approver: @handle | review: YYYY-MM | <ticket>
```

Example: `[RISK-ACCEPTED] /reports/latest reads a fixed file; rate limit 100 rpm enforced at APIM | control: gateway policy RL-7 | approver: @sec-lead | review: 2027-05 | SEC-188`

## 5. Governing dismissed findings

- **Who can dismiss**: use *delegated alert dismissal* for code scanning and secret scanning so developers raise dismissal **requests** that security reviewers approve; use *delegated bypass* for push protection.
- **Audit cadence**: quarterly (monthly for tier-1). Run `tools/alert-report.ps1 -DismissedOnly` or equivalent API query.
- **Red flags to reopen**:
  - blank / < 20-char justification
  - "Won't fix"/"Risk tolerable"/"No bandwidth" past its review date or without an approver
  - secret closed as FP/Won't fix but validity is **active**
  - "Used in tests" on a non-test path
  - "Vulnerable code not used" where the package is now imported in new code
  - dependency moved from dev → runtime (auto-dismissed alerts may auto-reopen)
- **Feed back**: recurring FPs → tuning backlog; recurring TPs → secure coding guidance / campaign.

## 6. Metrics

MTTR per tier · SLA breaches · % resolved by fix vs dismissal · dismissals by reason/team · PR-introduced alerts fixed before merge · open risk acceptances past review date.

## 7. Useful API calls

```bash
# Open code scanning alerts with critical security severity (repeat with severity=high)
gh api "repos/OWNER/REPO/code-scanning/alerts?state=open&severity=critical" --paginate
# Dismissed code scanning alerts with reasons/comments
gh api "repos/OWNER/REPO/code-scanning/alerts?state=dismissed" --paginate \
  --jq '.[] | [.number, .rule.id, .dismissed_reason, .dismissed_by.login, .dismissed_comment] | @tsv'
# Dependabot runtime alerts
gh api "repos/OWNER/REPO/dependabot/alerts?state=open&scope=runtime" --paginate
# Secret scanning alerts closed but still active
gh api "repos/OWNER/REPO/secret-scanning/alerts?state=resolved" --paginate \
  --jq '.[] | select(.validity=="active") | [.number, .secret_type_display_name, .resolution] | @tsv'
```

## References
- [Resolving code scanning alerts](https://docs.github.com/en/code-security/how-tos/manage-security-alerts/manage-code-scanning-alerts/resolve-alerts)
- [Dependabot auto-triage rules](https://docs.github.com/en/code-security/concepts/supply-chain-security/dependabot-auto-triage-rules)
- [Resolving secret scanning alerts](https://docs.github.com/en/code-security/how-tos/manage-security-alerts/manage-secret-scanning-alerts/resolving-alerts)
- [REST API: code scanning](https://docs.github.com/en/rest/code-scanning/code-scanning) · [Dependabot alerts](https://docs.github.com/en/rest/dependabot/alerts) · [Secret scanning](https://docs.github.com/en/rest/secret-scanning/secret-scanning)
