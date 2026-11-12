---
applyTo: "demo-app/**"
---

# Secure coding instructions for demo-app (used by Copilot when fixing security alerts)

These instructions are a **Session 2 training asset**: they show how custom instructions steer Copilot (including agentic
autofix and Copilot coding agent) toward the organisation's preferred remediation patterns.

## When fixing a security alert

- Keep the diff **minimal** and limited to the vulnerable data-flow path. Do not reformat unrelated code.
- Do **not** upgrade dependencies as part of a code fix; dependency upgrades go through Dependabot PRs.
- Never swallow errors (`catch {}`) to make a fix pass. Preserve existing status codes and response shapes.
- Add a `node:test` regression test under `demo-app/test/` that uses the exploit payload where practical.

## Approved patterns

- **SQL**: use parameterised queries with the sqlite3 API, e.g. `db.all(sql, [param], cb)`. Never concatenate user input into SQL.
- **OS commands**: never use `exec` or `shell: true`. Use `execFile(cmd, [args])` with an argument array and **allowlist**
  validation of each argument (e.g. `net.isIP`, strict regex anchored with `^…$` that cannot start with `-`). No blocklists.
- **HTML output**: encode user input for the output context, e.g. `_.escape(value)` (lodash is already a dependency).
  Never strip tags with regular expressions.
- **File paths**: resolve against a fixed base directory and verify the result stays inside it (`path.resolve` + `startsWith`),
  or validate with the existing `assertSafeFileName` helper in `src/utils/validate.js`.
- **Secrets**: read from environment / secret store and **fail fast** if missing. Never keep a hard-coded fallback value.
  Note in the PR description that the exposed credential must be **rotated** — removing it from code is not remediation.
