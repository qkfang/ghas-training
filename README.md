# ghas-training

A three-session GitHub Advanced Security (GHAS) training series. Each session is **45 min** (35 min content + 10 min hands-on demo)
and they all use the same intentionally vulnerable demo app.

| # | Session | Outcome |
|---|---|---|
| 1 | [**Prioritising, investigating & managing GHAS vulnerability alerts**](sessions/01-alert-triage/01-session-plan.md) — including false positives and dismissed findings | Attendees understand how alerts should be assessed and managed. |
| 2 | [**Remediating vulnerabilities with GitHub Copilot**](sessions/02-copilot-remediation/01-session-plan.md) — Copilot Autofix, understanding a vulnerability, generating & validating fixes, Copilot in the remediation workflow | Attendees can use Copilot to understand, fix and validate vulnerabilities safely. |
| 3 | [**GHAS security campaigns for security and risk**](sessions/03-security-campaigns/01-session-plan.md) — organising remediation, scope/objectives/timeframes, monitoring progress & outcomes, governance | Attendees can plan, run, monitor and govern remediation at scale. |

## Layout

Every session folder has the same five assets:

| File | What |
|---|---|
| `01-session-plan.md` | Run sheet with timings, objectives, speaker notes and pre-session checklist |
| `02-slides.md` | Slide deck (Marp markdown — `npx @marp-team/marp-cli sessions/<session>/02-slides.md --pptx`) |
| `03-*-playbook.md` | Attendee handout ([triage](sessions/01-alert-triage/03-triage-playbook.md) · [remediation](sessions/02-copilot-remediation/03-remediation-playbook.md) · [campaign](sessions/03-security-campaigns/03-campaign-playbook.md)) |
| `04-demo-script.md` | 10-minute demo script, setup, reset and fallbacks |
| `05-hands-on-exercise.md` | Exercise with answer key |

Shared assets:

| Path | What | Used in |
|---|---|---|
| [`demo-app/`](demo-app) | ⚠️ Intentionally vulnerable Node.js app producing code scanning, Dependabot and secret scanning alerts | 1, 2, 3 |
| [`tools/enable-ghas.ps1`](tools/enable-ghas.ps1) | Enable the GHAS features the demos need | 1, 2, 3 |
| [`tools/alert-report.ps1`](tools/alert-report.ps1) | Prioritised alert view + dismissed-alert audit | 1, 3 |
| [`tools/seed-dismissals.ps1`](tools/seed-dismissals.ps1) | Stage good/bad dismissals for the audit demo | 1 |
| [`tools/autofix.ps1`](tools/autofix.ps1) | Generate Copilot Autofix via REST API, commit to a branch, open a draft PR | 2 |
| [`tools/campaign.ps1`](tools/campaign.ps1) | Plan scope, create and monitor security campaigns via REST API (org only) | 3 |
| [`.github/codeql/`](.github/codeql), [`.github/workflows/codeql.yml`](.github/workflows/codeql.yml), [`.github/dependabot.yml`](.github/dependabot.yml) | CodeQL advanced setup (security-extended, `paths-ignore` tuning) and Dependabot config | 1, 2, 3 |
| [`.github/instructions/demo-app-security.instructions.md`](.github/instructions/demo-app-security.instructions.md) | Copilot custom instructions with approved secure-fix patterns | 2, 3 |

## Quick start

```powershell
./tools/enable-ghas.ps1 -EnableDependabotSecurityUpdates   # then add the custom secret pattern in the UI
gh workflow run codeql.yml
./tools/alert-report.ps1
./tools/seed-dismissals.ps1                               # before Session 1
./tools/autofix.ps1 -Alert <n>                            # Session 2: preview a Copilot Autofix
./tools/campaign.ps1 -Org <org> -Plan -Property tier=1    # Session 3: requires an organization
```

> Session 3 needs an **organization** (security campaigns aren't available on personal accounts) — fork this repo into a demo org.
> Scripts require PowerShell 7+ and an authenticated `gh` CLI.
