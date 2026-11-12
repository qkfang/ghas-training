# ghas-training

Training material for **"Prioritising, investigating & managing GHAS vulnerability alerts — including false positives and dismissed findings"** (45 min).

**Outcome:** attendees understand how alerts should be assessed and managed.

| Path | What |
|---|---|
| [`session/01-session-plan.md`](session/01-session-plan.md) | Run sheet with timings, objectives and speaker notes |
| [`session/02-slides.md`](session/02-slides.md) | Slide deck (Marp markdown — `npx @marp-team/marp-cli session/02-slides.md --pptx`) |
| [`session/03-triage-playbook.md`](session/03-triage-playbook.md) | Attendee handout: triage flow, priority tiers, dismissal standard, audit checklist |
| [`session/04-demo-script.md`](session/04-demo-script.md) | 10-minute hands-on demo script, setup and fallbacks |
| [`session/05-hands-on-exercise.md`](session/05-hands-on-exercise.md) | Triage exercise with answer key |
| [`demo-app/`](demo-app) | ⚠️ Intentionally vulnerable Node.js app producing code scanning, Dependabot and secret scanning alerts |
| [`tools/`](tools) | `enable-ghas.ps1` (setup), `alert-report.ps1` (prioritised view + dismissal audit), `seed-dismissals.ps1` (stage demo dismissals) |
| [`.github/`](.github) | CodeQL advanced setup (security-extended, `paths-ignore` tuning) and Dependabot config |

## Quick start

```powershell
./tools/enable-ghas.ps1 -EnableDependabotSecurityUpdates   # then add the custom secret pattern in the UI
gh workflow run codeql.yml
./tools/alert-report.ps1
./tools/seed-dismissals.ps1                               # before the session
```