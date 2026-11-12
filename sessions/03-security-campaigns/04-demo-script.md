# Hands-on demo script (10 minutes) — GHAS security campaigns

Organization: `<demo-org>` (campaigns are **org-only**) · Repo: `<demo-org>/ghas-training` · Tools: [`tools/campaign.ps1`](../../tools/campaign.ps1), [`tools/alert-report.ps1`](../../tools/alert-report.ps1)

## Setup (2 days before — ~45 min)

```powershell
$org = '<demo-org>'

# 1. Get the demo repo into the org (fork, or transfer a copy) and enable GHAS features + run CodeQL
gh repo fork qkfang/ghas-training --org $org --clone=false
./tools/enable-ghas.ps1 -Repo "$org/ghas-training" -EnableDependabotSecurityUpdates
gh workflow enable codeql.yml -R "$org/ghas-training"     # forks start with Actions workflows disabled
gh workflow run codeql.yml -R "$org/ghas-training"
#    + create the "ACME API key" custom secret pattern (see Session 1 demo script)

# 2. Custom property for criticality: create 'tier' (single select 1/2/3) in org Settings > Custom properties,
#    then set it on the repo:
'{"repository_names":["ghas-training"],"properties":[{"property_name":"tier","value":"1"}]}' |
  gh api -X PATCH "orgs/$org/properties/values" --input -

# 3. Check scope and a suggested due date
./tools/campaign.ps1 -Org $org -Plan -Rule js/sql-injection,js/reflected-xss,js/command-line-injection -Property tier=1 -WeeklyCapacity 2

# 4. Pre-create a "history" campaign a few days early so the tracking view has data (e.g. rate limiting)
./tools/campaign.ps1 -Org $org -Create -Name 'Missing rate limiting (CWE-770)' `
  -Description 'Add rate limiting or document the gateway control. Guide: <link>' `
  -Rule js/missing-rate-limiting -EndsAt (Get-Date).AddDays(21) -Manager <your-login> -ContactLink <discussion-url>
```

**Browser tabs to pre-open** (zoom 125%):
1. Org → **Security and quality → Campaigns**
2. Org → **Security and quality → Alerts** (code scanning) — security overview
3. `<demo-org>/ghas-training` → **Security → Campaigns** (developer view)
4. Repo **Issues** (for the tracking issue)
5. Terminal in repo root

**Reset after the session:** close (or delete) the campaign created live, close its tracking issue, reopen anything dismissed live.

---

## Segment 1 — Organise: why a campaign (1 min)

1. Open org **Security and quality → Campaigns**. Show the pre-created campaign: name, due date, manager, alert counts by status.
2. Talk track: *"Session 1 told us what matters; Session 2 made one fix cheap. A campaign turns 'the backlog' into themed, owned, dated work — in the developer's repo, not a spreadsheet."*

## Segment 2 — Scope, objective, timeframe → create (3 min)

1. Org **Security overview → code scanning alerts**. Build the scope live:
   ```text
   is:open tool:CodeQL props.tier:1
   ```
   then narrow to injection rules (or start from a **template**, e.g. *Cross-site scripting (CWE-79)*). Add `autofix:supported` and point out the count change.
2. Click **Create campaign** (from the filtered view or template). Fill in:
   - **Name:** `Injection in tier-1 apps`
   - **Short description:** objective + why + guidance:
     *"Remove SQL and command injection and reflected XSS from tier-1 internet-facing apps. Target: ≥ 90 % fixed (not dismissed), 0 open critical. Use parameterised queries / execFile — see .github/instructions/demo-app-security.instructions.md."*
   - **Due date:** from `campaign.ps1 -Plan -WeeklyCapacity` output (setup step 3) — *"capacity, not wishful thinking"*.
   - **Manager:** yourself / AppSec team · **Contact link:** the Discussion.
   - **Generate issues:** on.
3. **Save as draft** first — *"review scope with engineering leads"* — then **Publish**.
   - *Alternative:* show the same thing scripted: `./tools/campaign.ps1 -Org $org -Create …` (published immediately; drafts are UI-only).

## Segment 3 — Developer experience (2 min)

1. Switch to repo **Security → Campaigns** → the new campaign: alerts, due date, manager, contact.
2. Open the auto-created **tracking issue** in the repo — description, contact link and due date are synced.
3. On the SQL injection alert in the campaign: **Copilot Autofix** is already suggested → mention *Create PR with fix* (Session 2). If agentic autofix is enabled: select the injection alerts → **Assign to Copilot** (≤ 25 per session → one draft PR).
4. Create a branch/PR from one alert → it moves to **In progress**.

## Segment 4 — Monitor progress & outcomes (2 min)

1. Open the campaign's **tracking page**: progress (closed / in progress / open), status vs due date, Autofix count, by-repo breakdown.
2. Terminal:
   ```powershell
   ./tools/campaign.ps1 -Org $org
   ```
   Walk the columns: *Closed %* vs *Time %* → ON-TRACK / AT-RISK; flags like `NOT-STARTED`, `NO-CONTACT-LINK`.
   Talk track: *"'Closed' includes dismissed. A campaign that hits 100 % by dismissing has moved risk, not removed it."*

## Segment 5 — Governance & close-out (2 min)

1. Dismiss one alert in the campaign **badly** (e.g. *Won't fix*, comment "later") → run:
   ```powershell
   ./tools/alert-report.ps1 -Repo "$org/ghas-training" -DismissedOnly
   ```
   It's flagged `WEAK-JUSTIFICATION` / `NO-APPROVAL-OR-REVIEW-DATE` → *"campaign dismissals follow the Session 1 standard and delegated dismissal."*
2. Show closing a campaign (UI **Close campaign**, or `gh api -X PATCH orgs/$org/campaigns/<n> -f state=closed`) and what happens: tracking issues get a comment.
3. Close: *"Close on time, report fixed-vs-dismissed against the objective, run a retro, and put a gate (rulesets + PR Autofix) in place so this class doesn't come back."*

---

## Fallbacks
- **No org / no security manager role**: use screenshots of each step + run `tools/campaign.ps1 -Plan` on any org you can read; describe the UI.
- **`props.tier` filter unavailable**: filter by repository name instead.
- **Tracking issue not yet created**: show the pre-created campaign's issue.
- **Running long**: skip Segment 3 step 4 and Segment 5 step 2.

## Optional attendee follow-along
In an org where you're a security manager, fill in the **campaign canvas** from [`03-campaign-playbook.md`](03-campaign-playbook.md),
run `tools/campaign.ps1 -Plan`, then complete [`05-hands-on-exercise.md`](05-hands-on-exercise.md).
