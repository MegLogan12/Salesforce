# LOVING-SF — Claude Code Notes

## Purpose of this CLI foundation

The Salesforce CLI is connected to the **LOVING production org** so Claude Code
can safely inspect metadata, retrieve org information, run read-only checks, and
perform validation-only deployment checks before any approved production change.

**Allowed operations:**
- Authenticate to production (`sf org login web`)
- Inspect and retrieve metadata (`sf project retrieve`, `sf org display`, etc.)
- Validation-only deploys (`sf project deploy validate`) — dry run, no org changes

**Never allowed without explicit written approval from Megan Logan:**
- `sf project deploy start` — deploys metadata to production
- Any command that modifies, deletes, renames, deactivates, or overwrites
  production metadata, records, or configuration
- Any command that modifies production data

When in doubt, do not run the command. Ask first.

---

## Session startup hook

**File:** `.claude/hooks/session-start.sh`
**Registered in:** `.claude/settings.json`

### What it does
Installs `@salesforce/cli@2.134.6` (pinned) globally via npm so the `sf`
command is available for the rest of the session.

### When it runs
On every `SessionStart` event in a remote Claude Code web session
(`CLAUDE_CODE_REMOTE=true`). It is a no-op in local CLI sessions.

### Why it is synchronous
The hook runs synchronously before the session becomes interactive (~20 s on
first install). This guarantees `sf` is ready before any command runs and
avoids race conditions where Claude might attempt a deploy or validate before
the CLI is present. Do not switch to async without careful testing.

### Pinned version
The CLI is pinned to `@salesforce/cli@2.134.6` — the version validated in this
repo. To upgrade, test the new version manually, update the pin in
`.claude/hooks/session-start.sh`, and commit the change.

---

## Authenticating the production org after session start

The hook installs the CLI but does **not** authenticate any org.
Run the following after the session starts to connect to production:

```bash
sf org login web --alias loving-prod --instance-url https://login.salesforce.com
```

Authentication tokens are stored in `~/.sf/` on the container only and are
never written to the repo. They are lost when the session ends — you must
re-authenticate each session.

---

## What NOT to commit

Never commit any of the following:

- Auth tokens, access tokens, refresh tokens
- Files containing org usernames or org IDs
- `.sf/` or `.sfdx/` directories
- Any `*.auth.json` or similar credential files
- Scratch org definition files that contain internal org details

These are all covered by `.gitignore`. If you accidentally stage one, run
`git reset HEAD <file>` before committing.

---

## Smoke-test commands

Run these in order after authenticating to confirm the CLI and project are
wired up correctly against the production org.

```bash
# 1. Confirm CLI version
sf --version

# 2. List authenticated orgs (confirm loving-prod appears)
sf org list

# 3. Validate metadata (dry-run deploy — no changes made to the org)
sf project deploy validate \
  --source-dir force-app \
  --target-org loving-prod \
  --test-level RunSpecifiedTests \
  --tests LOVING_WorkOrderTriggerHandlerTest

# 4. Run Apex tests against the production org
sf apex run test \
  --class-names LOVING_WorkOrderTriggerHandlerTest \
  --target-org loving-prod \
  --result-format human \
  --wait 10
```

`deploy validate` is always safe — it is a dry run and makes no changes to
the org. Do NOT run `sf project deploy start`. Any production deployment
requires explicit written approval before Claude will execute it.
