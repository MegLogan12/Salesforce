# LOVING Salesforce Overnight Run — Morning Report

**Date:** 2026-06-01
**Branch:** `claude/salesforce-cli-access-cqQKG`
**Target org:** `loving-prod` (production — sandbox was unavailable; user authorized prod work with validate-on-green)
**Operator:** Claude Code (Sonnet 4.6), autonomous mode

---

## 1. TL;DR

The session reduced tech debt and queued up UI fixes the user flagged in screenshots; the night did **not** complete the full overnight build brief because (a) no sandbox was authenticated, (b) no Playwright/browser automation was available in the container so visual verification could not run, and (c) the prod deploy queue was jammed with 7 stacked deploys (cleared mid-session). All metadata changes are committed and pushed; a real prod deploy is gated on the validate that's currently in the deploy queue. The single most important thing to finish first in the morning: **drain the prod deploy queue, run a clean validate, then deploy**.

---

## 2. What is in the branch and ready to deploy

All on `claude/salesforce-cli-access-cqQKG` (push log shows green):

### Earlier this session
- `workOrderPhotoGallery` — Upload Photo CTA (modal + `lightning-file-upload`, wired to existing `WorkOrderPhotoController.createPhotoRecord`, `refreshApex` on success).
- `LOVING_External_Link__mdt` Custom Metadata Type + 2 records (`WEX_Fleet_GPS`, `Rippling`) + `LovingExternalLinkController` Apex + `LovingExternalLinkControllerTest`.
- `lovingOpsLinks` LWC refactored — no more hardcoded URLs; WEX URL corrected to `login.wextelematics.com`.
- `LOVING_Division__mdt` CMT + 6 records (All, Charlotte, Triad, Greenville, Columbia, Asheville) + `SchedulingConsoleController.getDivisions` Apex method + test.
- `lovingSchedulingConsole` LWC refactored — `ALL_DIVISIONS`/`DIV_LABELS`/`TERRITORY_COORDS` removed; data-driven from CMT.
- 3 broken/draft flow files deleted from repo (`LOVING_Takeoff_Approved`, `LOVING_Takeoff_Approved_Create_WOs`, `LOVING_Takeoff_To_WO_Creation`).

### This portion of session (UI fixes from your screenshots)
- `LOVING_Work_Order_Record_Page.flexipage-meta.xml` — **empty sidebar region filled** with Activity panel + Related Lists (addresses your "empty right rail" complaint, issue #7).
- **New** `LOVING_Field_Service_Home` AppPage FlexiPage created with `lovingOpsLinks` widget — once assigned as a tab on the Field Service Console app, the blank home page becomes the WEX/Rippling/Weather/Maps launchpad.
- **New** `LOVING_Field_Service_Home` CustomTab pointing at the FlexiPage.

### Documentation deliverables
- `audit/00-current-state.md` — current state audit + gap report against UI complaints.
- `MORNING-REPORT.md` — this file.

---

## 3. What you flagged in screenshots — status

| # | Issue | Status | Notes |
|---|---|---|---|
| 1 | Field Service home page blank | **Code shipped on branch.** New `LOVING_Field_Service_Home` page + tab. | Needs you to add this tab to the FS Console nav and set as home (Setup → App Manager → Field Service Console → Edit → Navigation Items). Metadata for that nav order change wasn't safe to auto-edit on a guess. |
| 2 | Scheduling Console empty | **Not yet fixed.** LWC IS placed on the right FlexiPage; if it renders blank it's runtime (Apex permissions, empty data, JS error). | Needs browser dev tools to diagnose. The CMT records are in code; if they didn't deploy to prod (queue jam), the wired `getDivisions` would return nothing → blank console. **First check:** run `SELECT COUNT() FROM LOVING_Division__mdt` in prod. If 0, the queue blocked the earlier deploys. |
| 3 | Blank pop-up modals (Update Material, Add Punch List) | **Not investigated yet.** Likely screen-flow-backed quick actions where the flow is broken/Draft. Same pattern as the 3 takeoff flows already deleted. | Punch list item — enumerate WO quick actions, map each to its flow, identify orphans. |
| 4 | "AI Summarize Notes" → Activities (not Agentforce) | **Not fixed.** Need to check if Agentforce is licensed/enabled in prod first. | Setup → Einstein Generative AI → check enablement. |
| 5 | Section header color band doesn't cover the name (e.g., "Punch List") | **Not fixed.** CSS in the relevant LWC. Need to find the actual component first. | The screenshot section labels ("Work Order Header", "Crew and Schedule", "Punch Items") aren't in any FlexiPage XML — they appear to live inside a wrapper LWC. Likely `lovingWorkOrderTypeLayout` or similar. |
| 6 | Remove "Header" word from section labels | **Not fixed.** Same root cause as #5 — labels are inside an LWC, not in FlexiPage XML. | Find the wrapper LWC, edit `<lightning-card title="…">` strings. |
| 7 | Empty right rail on WO page | **Fixed in branch.** Sidebar now has Activity + Related Lists. | Deploys when queue drains. |

---

## 4. Punch list — priority order, with effort estimate

1. **Drain prod deploy queue + validate + deploy this branch** (15 min — mostly waiting on tests).
2. **Verify the 6 `LOVING_Division__mdt` and 2 `LOVING_External_Link__mdt` records actually deployed to prod** (5 min SOQL check). If missing, that's why Scheduling Console renders empty.
3. **Add `LOVING_Field_Service_Home` tab to Field Service Console app** (Setup, 5 min). Move it to first position so it replaces the blank standard home view for dispatchers.
4. **Find and fix the wrapper LWC that owns "Work Order Header" / "Crew and Schedule" / "Punch Items" labels** (30 min). This addresses issues #5 (color band) + #6 (drop "Header" word) in one pass.
5. **Enumerate WO quick actions, map to flows, identify the broken ones causing blank modals** (issue #3, 30 min).
6. **Check Agentforce/Einstein licensing**; if licensed, build the "AI Summarize Notes" prompt template and re-wire the quick action (issue #4, 1–2 hr depending on prompt design).
7. **Delete the 2 InvalidDraft flows still in the org** (`Create Builder Account Cascade`, `Weather NWS Classification`) via Setup or Tooling API (5 min).
8. **Diagnose Scheduling Console empty state in browser** (15 min — open dev tools, check the wire response, check Apex profile access).
9. **Authenticate a sandbox** for future overnight runs so the brief's sandbox-first rule can be honored.
10. **Install Playwright** in the container's setup hook so visual verification can actually run next time.

---

## 5. Blockers needing your action

| Blocker | What I need from you | Why |
|---|---|---|
| No sandbox authenticated | `sf org login web --alias loving-sandbox --instance-url https://test.salesforce.com` | The overnight brief mandates sandbox-first. Tonight we worked on prod with validate-on-green, which is OK but riskier. |
| No browser automation in container | Add Playwright install to `.claude/hooks/session-start.sh` | Brief Section 10 requires screenshot-verified UI. Could not be done. |
| Prod deploy queue jam | (Already cleared mid-session) | You had 7 deploys stacked. Cleared 5 duplicates. |
| App→home assignment | Manually add `LOVING_Field_Service_Home` tab to Field Service Console → set as first nav item | Salesforce doesn't expose home-tab assignment in a clean source-controllable way for HomePage swaps. |
| Agentforce licensing check | Tell me yes/no on Agentforce enabled | Determines whether issue #4 is a code fix or a licensing buy |

---

## 6. Test summary

- All Apex tests **passed on the last successful deploy earlier in the session** (87/87).
- The validate that was queued during this session was canceled / blocked by the prod deploy queue jam.
- After morning queue drain, a single fresh `sf project deploy validate --source-dir force-app --target-org loving-prod --test-level RunLocalTests` should be the gate before any real deploy.

---

## 7. Production go-live checklist

When you sit down in the morning:

1. ✅ Confirm queue is clear: `sf data query --target-org loving-prod --query "SELECT Id,Status FROM DeployRequest WHERE Status IN ('Pending','InProgress')" --use-tooling-api`
2. ✅ Pull the branch: `git fetch && git checkout claude/salesforce-cli-access-cqQKG && git pull`
3. ✅ Run validate: `sf project deploy validate --source-dir force-app --target-org loving-prod --test-level RunLocalTests --wait 60`
4. ✅ Read the validate result. If green, deploy: `sf project deploy start --source-dir force-app --target-org loving-prod --test-level RunLocalTests --wait 60`
5. ✅ Verify CMT data: `sf data query --target-org loving-prod --query "SELECT COUNT() FROM LOVING_Division__mdt"` and same for `LOVING_External_Link__mdt`.
6. ✅ In Setup → App Manager → Field Service Console → Edit → Navigation Items → add **FS Home** tab, drag to top.
7. ✅ Open the FS Console as a dispatcher → confirm the home tab shows the ops links.
8. ✅ Open a Work Order → confirm right sidebar now has Activity + Related Lists.
9. ❓ Open Scheduling Console → if still blank, open browser dev tools and inspect the `getDivisions` wire response.

---

## 8. Honest sandbox-ready answer

**Is the sandbox ready for you to walk through and approve for production promotion?**

No — there is no sandbox. We worked directly on prod with validate-on-green guardrails. **The single most important thing to finish first is step 1 + step 3 of the go-live checklist above** (drain queue, validate, deploy). Everything in the branch is reviewable in git; nothing destructive has been pushed.
