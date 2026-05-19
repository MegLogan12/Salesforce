# LOVING-SF — Claude Code Notes

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

## Authenticating an org after session start

The hook installs the CLI but does **not** authenticate any org.
Run one of the following after the session starts:

```bash
# Production / Developer Edition
sf org login web --alias loving-prod

# Sandbox
sf org login web --alias loving-sandbox --instance-url https://test.salesforce.com
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

Run these in order after authenticating an org to confirm the CLI and project
are wired up correctly.

```bash
# 1. Confirm CLI version
sf --version

# 2. List authenticated orgs
sf org list

# 3. Validate metadata (dry-run deploy — no changes made to the org)
sf project deploy validate \
  --source-dir force-app \
  --target-org <alias> \
  --test-level RunSpecifiedTests \
  --tests LOVING_WorkOrderTriggerHandlerTest

# 4. Run Apex tests against an authenticated org
sf apex run test \
  --class-names LOVING_WorkOrderTriggerHandlerTest \
  --target-org <alias> \
  --result-format human \
  --wait 10
```

Replace `<alias>` with the alias you used in `sf org login web --alias ...`.

**Do not run `sf project deploy start` without explicit approval.** Validation
(`deploy validate`) is always safe — it performs a dry run with no org changes.
