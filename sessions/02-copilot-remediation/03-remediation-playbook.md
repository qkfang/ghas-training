# Copilot Remediation Playbook (handout)

A one-page reference for remediating GHAS code scanning alerts with GitHub Copilot.
Builds on the [Session 1 triage playbook](../01-alert-triage/03-triage-playbook.md) — only **fix** what you've confirmed is real.

---

## 1. Which Copilot feature?

| | Copilot Autofix | Agentic autofix (assign to Copilot) | Copilot Chat / agent mode (IDE) |
|---|---|---|---|
| Best for | One alert, localised fix | Several related alerts, multi-file, needs validation | Design changes, refactors, unfamiliar code, failing upgrades |
| Entry point | PR comment · alert **Generate fix** · campaign · REST API | **Assign** alert(s) to Copilot (alert page or campaign, ≤ 25 per assignment) | Your editor |
| Output | Suggested diff + explanation | Draft PR, fix validated by re-running CodeQL | Local changes you commit |
| Enablement | On by default with CodeQL; private/internal need GitHub Code Security | Org owner / security manager enables (repo admin for eligible personal public repos); not for EMU | Copilot licence |
| Cost | No AI credits | Code Security AI credits + Actions minutes | Copilot plan usage |

**Not a fit:** secrets (rotate first — Copilot can only help remove from code), risk acceptance, infrastructure-only fixes, alerts from tools other than CodeQL (no Autofix).

## 2. Understand before you fix

```text
CodeQL rule help + Show paths  ──►  Autofix explanation  ──►  Copilot Chat questions  ──►  Verdict
   (ground truth)                    (why + what changes)       (exploit, scope, siblings)    TP? → fix   FP? → Session 1 dismissal path
```

Prompt starters (paste the alert URL or rule ID and open the file for context):

- *"Explain this `<rule-id>` alert in `<file>`: what is the source, the sink, and the attacker precondition?"*
- *"Write a curl request that would demonstrate this against a local instance."*
- *"Find other places in this repo where `<source>` reaches `<sink-type>` without validation."*
- *"Fix this using `<safe API>`; keep the response format and error handling unchanged; add a `node:test` regression test."*

## 3. Validation checklist (every suggested fix)

- [ ] **Explanation read** and it matches the CodeQL path.
- [ ] **Root cause** removed — safe API (parameterised query, `execFile` + arg array, context-aware encoding), not a blocklist.
- [ ] Diff touches only what's needed; **no unexpected dependency**.
- [ ] **CodeQL check on the PR**: target alert shows as fixed; **no new alerts**.
- [ ] **Tests pass**; a **regression test** with the exploit payload is added.
- [ ] Behaviour preserved (API contract, status codes, error paths, performance).
- [ ] **Sibling paths** with the same pattern fixed or tracked.
- [ ] Reviewed and merged by a **human** (code owner / security reviewer for sensitive paths).

## 4. Red flags — edit or reject

| Red flag | Why it's wrong | Better |
|---|---|---|
| `input.replace(/[;&\|]/g, '')` | Blocklists miss encodings/alternatives; still a shell | `execFile` with args array + allowlist |
| `process.env.KEY \|\| 'old-key'` | Secret still in code and history; unrotated | Fail fast if unset; **rotate**; load from secret store |
| Renames / wrappers that hide the flow | Silences the tool, bug remains | Fix the data flow |
| `try { … } catch {}` added | Hides failures | Explicit error handling |
| Large unrelated changes | Hard to review, regressions | Ask for a minimal diff |
| Output-encoding only for SQLi | Wrong layer | Parameterise the query |

## 5. Workflow by stream

| Stream | Flow | Owner |
|---|---|---|
| **PR gate** (new alerts) | Autofix comment → accept / edit → CodeQL re-runs → review → merge | PR author |
| **Backlog** (P0–P2) | Understand → Generate fix → **Create PR** (draft) → validate → review → merge | Assigned dev / champion |
| **Backlog, related alerts** | Assign to Copilot → draft PR → validate & extend tests → review → merge | Assigned dev |
| **Campaign** (Session 3) | Campaign view → Autofix / Assign to Copilot → PR linked to campaign | Repo team; campaign manager supports |
| **Scripted / bulk** | `tools/autofix.ps1 -Alert n -CreatePR` (REST API) → review each PR | Champion |

## 6. Guardrails

- **Rulesets**: require PR + review + passing **CodeQL** check (code scanning merge protection) on default branch.
- **CODEOWNERS / security reviewers** on auth, crypto, data-access paths.
- **No auto-merge** for security fixes; Autofix PRs open as **drafts**.
- **Custom instructions** for secure patterns (see [`.github/instructions/demo-app-security.instructions.md`](../../.github/instructions/demo-app-security.instructions.md)).
- Watch **cost**: agentic sessions consume AI credits + Actions minutes — use for batches that justify it.

## 7. Metrics

MTTR before/after Autofix · alerts fixed in PR vs reaching default branch · Autofix acceptance / edit / reject rate · fix vs dismiss ratio · reopened (regressed) alerts.

## 8. Useful API calls

```bash
# Request an autofix (202 = generating, 200 = already exists)
gh api -X POST repos/OWNER/REPO/code-scanning/alerts/ALERT/autofix
# Poll status: pending | success | error | outdated
gh api repos/OWNER/REPO/code-scanning/alerts/ALERT/autofix --jq '.status, .description'
# Commit the fix to an existing branch, then open a draft PR
gh api -X POST repos/OWNER/REPO/code-scanning/alerts/ALERT/autofix/commits \
  -f target_ref=refs/heads/autofix/alert-ALERT -f message="Fix alert ALERT (Copilot Autofix)"
gh pr create --draft --head autofix/alert-ALERT --title "Fix code scanning alert ALERT"
```

Or use [`tools/autofix.ps1`](../../tools/autofix.ps1), which wraps all of the above.

## References
- [About autofix for code scanning](https://docs.github.com/en/code-security/concepts/code-scanning/autofix-for-code-scanning)
- [Resolving code scanning alerts — fixing alerts with Copilot](https://docs.github.com/en/code-security/how-tos/manage-security-alerts/manage-code-scanning-alerts/resolve-alerts#fixing-alerts-with-copilot)
- [Managing access to agentic autofix](https://docs.github.com/en/code-security/how-tos/manage-security-alerts/manage-code-scanning-alerts/managing-access-to-agentic-autofix-for-code-scanning)
- [REST API: code scanning autofix](https://docs.github.com/en/rest/code-scanning/code-scanning#create-an-autofix-for-a-code-scanning-alert)
- [Adding custom instructions for Copilot](https://docs.github.com/en/copilot/how-tos/copilot-on-github/customize-copilot/add-custom-instructions)
