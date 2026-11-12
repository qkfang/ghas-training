# Session 2 plan — Remediating vulnerabilities with GitHub Copilot

| | |
|---|---|
| **Duration** | 45 minutes (35 min content + 10 min hands-on demo) |
| **Audience** | Developers, tech leads, AppSec champions, security engineers |
| **Outcome** | Attendees can use GitHub Copilot to **understand** a vulnerability, **generate** a fix with Copilot Autofix, **validate** it like any other change, and fit Copilot into the **remediation workflow**. |
| **Prereqs** | [Session 1](../01-alert-triage/01-session-plan.md) (or equivalent: knows how alerts are prioritised and investigated). Basic Git/PR workflow. |
| **Materials** | [`02-slides.md`](02-slides.md) (Marp) · [`03-remediation-playbook.md`](03-remediation-playbook.md) (handout) · [`04-demo-script.md`](04-demo-script.md) · [`05-hands-on-exercise.md`](05-hands-on-exercise.md) · [`../../demo-app`](../../demo-app) · [`../../tools/autofix.ps1`](../../tools/autofix.ps1) · [`../../.github/instructions/demo-app-security.instructions.md`](../../.github/instructions/demo-app-security.instructions.md) |

## Learning objectives

By the end, attendees can:

1. Describe **Copilot Autofix** vs **agentic autofix** (assign to Copilot): what each does, entry points, enablement, cost and limits.
2. Use Copilot (Autofix explanation + Copilot Chat) alongside CodeQL's data-flow path to **understand** an alert and confirm it is real.
3. **Generate** a suggested fix and **validate** it: root cause fixed, alert closes, tests pass, regression test added, no new risk.
4. Recognise **red flags** in AI-suggested security fixes (blocklists, fallback secrets, tool-silencing).
5. Choose the right Copilot entry point for each **remediation stream** (PR gate vs backlog) and set **guardrails** (custom instructions, rulesets, human review).

## Run sheet

| Time | Min | Section | Slides | Key message |
|---|---|---|---|---|
| 0:00 | 3 | Welcome, recap of Session 1, outcome | 1–3 | Make **Fix** the cheap, default option. |
| 0:03 | 6 | **GitHub Copilot Autofix** — two flavours, entry points, limits | 4–7 | Same engine, four entry points; know when it can't help. |
| 0:09 | 6 | **Using Copilot to understand a vulnerability** | 8–10 | You can't review a fix you don't understand. |
| 0:15 | 9 | **Generating & validating a suggested fix** | 11–14 | Treat the suggestion as a teammate's PR. |
| 0:24 | 9 | **Copilot in the remediation workflow** — streams, tool choice, instructions, guardrails, metrics | 15–19 | Copilot shortens time-to-fix; it doesn't move accountability. |
| 0:33 | 10 | **Hands-on demo** (`demo-app`) | 20 | Understand → fix → validate on real alerts. |
| 0:43 | 2 | Close: takeaways & handout | 21 | Use the playbook. |

> Timing tip: if running late, cut slide 19 (metrics) and the agentic autofix part of the demo (Segment 5).

## Speaker notes by section

### 1. Welcome & recap (3 min)
- Recap Session 1 in one breath: prioritise by risk → investigate to a verdict → **Fix → Tune → Dismiss**.
- Today is about the **Fix** branch. The cheaper fixing is, the fewer risk acceptances you have to govern.
- Poll: "Who has used Copilot Autofix on a security alert? Who merged it without changes?"

### 2. GitHub Copilot Autofix (6 min)
- **Copilot Autofix**: LLM + CodeQL analysis (path, rule help) + nearby code → one suggested change + explanation for one alert. On by default wherever CodeQL runs; public repos and private/internal repos with **GitHub Code Security**. No AI credits consumed.
- **Agentic autofix**: *assign* one or more alerts to Copilot. It explores the codebase, generates a fix, **validates by re-running CodeQL**, and opens a **draft PR**. Must be enabled by an org owner/security manager (repo admin for eligible personal public repos); consumes **Code Security AI credits + Actions minutes**; honours **custom instructions**; not available to EMU-owned repos.
- Entry points: PR comments (new alerts), alert page **Generate fix** (backlog), **security campaigns** (Session 3; assign up to 25 alerts to Copilot per session), **REST API** (`/autofix`, `/autofix/commits`).
- Limits: not every alert is supported (`autofix:supported` filter); suggestions may be partial or behaviour-changing; agentic autofix can't confirm fixes for `security-extended`, custom queries or third-party tools; it can't rotate secrets or accept risk.
- *Demo repo note*: this repo runs `security-extended`, so rules like `js/missing-rate-limiting` and `js/hardcoded-credentials` won't be validated by agentic autofix — a useful talking point.

### 3. Using Copilot to understand a vulnerability (6 min)
- Why understand first: reviewability, false positives (Session 1), fixing the class, learning.
- Order of evidence: **CodeQL** (rule help, Show paths = ground truth) → **Autofix explanation** → **Copilot Chat** for "how would an attacker exploit this?", "where else?", "write me a PoC request for local testing".
- Prompt quality matters: give **constraints** (existing API, style, behaviour to keep) and **evidence** (alert, path, rule ID).
- If Copilot says "this looks safe" — that is an *opinion*. Verify against the path and code; then use the Session 1 dismissal standard.

### 4. Generating & validating a suggested fix (9 min)
- Read the **explanation before the diff**. Check what changed and whether it's on the data-flow path.
- **Create PR with fix** (draft) so CI, CodeQL and review run. Don't commit straight to `main`.
- Validation checklist (slide 12): root cause, alert closes in the PR's CodeQL check with no new alerts, tests pass, **regression test with the exploit payload**, side effects, completeness (sibling paths), human owner approves.
- Red flags (slide 13): blocklists, `process.env.X || 'old-secret'`, renaming to dodge the query, swallowed errors, unrelated changes/dependencies.
- Walk the command-injection example (slide 14): blocklist vs `execFile` + allowlist.

### 5. Copilot in the remediation workflow (9 min)
- Two streams from Session 1: **PR gate** (Autofix comment → accept/edit → CodeQL re-runs) and **backlog burn-down** (Generate fix / Assign to Copilot / IDE).
- Tool choice table (slide 16). Emphasise: secrets → **rotate first**; Copilot can help remove from code and add secret-store loading, never revoke.
- **Custom instructions** encode your secure patterns once; show [`.github/instructions/demo-app-security.instructions.md`](../../.github/instructions/demo-app-security.instructions.md).
- Guardrails: rulesets requiring review + CodeQL check, CODEOWNERS on sensitive paths, no auto-merge for security fixes, cost awareness.
- Metrics: MTTR before/after, fixed-in-PR, acceptance/edit rate, fix vs dismiss, regressions.

### 6. Demo (10 min) — see [`04-demo-script.md`](04-demo-script.md)

### 7. Close (2 min)
- Takeaways: **Understand first. Autofix is a suggestion. Validate like any change. Right tool per stream. Humans merge.**
- Bridge to Session 3: "Fixing one alert is easy now — next we organise fixing hundreds across teams with **security campaigns**."

## Pre-session checklist (T-1 day)
- [ ] Session 1 setup done (GHAS enabled, CodeQL has run, alerts exist — see [`../../demo-app/README.md`](../../demo-app/README.md)).
- [ ] Copilot Autofix not disabled for the repo/org (Settings → Advanced Security → Code scanning → Copilot Autofix).
- [ ] *Optional:* agentic autofix enabled (org: Settings → Advanced Security; personal public repo: repo settings) if you'll show **Assign to Copilot**.
- [ ] Copilot Chat available to the presenter on github.com and in VS Code.
- [ ] Pre-generate a fallback: `./tools/autofix.ps1 -Alert <sql-injection #>` and screenshot the result.
- [ ] Make sure no open autofix PRs remain from a previous run (`gh pr list --search "head:autofix/"`).
