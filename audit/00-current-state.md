# LOVING Salesforce — Current State Audit

**Audit run:** 2026-06-01 overnight session
**Target org:** `loving-prod` (production)
**Auditor:** Claude Code (autonomous run per Overnight Build Brief)
**Branch:** `claude/salesforce-cli-access-cqQKG`

> NOTE: Brief requested sandbox-first. No sandbox auth is available in this container. User authorized continued work against `loving-prod` with validate-before-deploy. All findings below are from repo metadata + read-only checks; production deploys are gated on green validate per user instruction.

---

## 1. Environment & Auth

| Item | State |
|---|---|
| sf CLI version | 2.134.6 (pinned in `.claude/hooks/session-start.sh`) |
| Authenticated orgs | `loving-prod` only (`megan.logan@thelovingcompanies.com`, 00Da500001UEK0HEAX) |
| Sandbox | **None authenticated** — blocker for brief Section 4.1 |
| Browser automation (Playwright/Puppeteer) | Not installed — blocker for brief Section 10 visual verification |

**Action for Meg in the morning:** authenticate the sandbox so future overnight runs honor the brief:
```
sf org login web --alias loving-sandbox --instance-url https://test.salesforce.com
```

---

## 2. Repository inventory (from `force-app/main/default/`)

| Metadata type | Count (approx) |
|---|---|
| Apex classes | ~80+ (incl. `SchedulingConsoleController`, `LovingExternalLinkController`, `WorkOrderPhotoController`, `DispatchMapController`, `LOVING_WorkOrderTriggerHandler`) |
| LWCs | `lovingSchedulingConsole`, `lovingOpsLinks`, `lovingDispatchMap`, `workOrderPhotoGallery`, `workOrderPipelineKanban`, more |
| FlexiPages | 20+ (record pages, app pages, utility bars) |
| Custom Objects | 16+ custom (Work_Order__c, Punch_Item__c, Photo__c, Crew__c, Community__c, Purchase_Order__c, etc.) |
| Custom Metadata Types | `LOVING_External_Link__mdt` (2 records), `LOVING_Division__mdt` (6 records) — both newly deployed |
| Flows | 18 in repo (after deletion of 3 broken/draft); ~28 draft + 2 InvalidDraft remain in org |
| Tabs | `Scheduling_Console`, `Dispatch_Map`, several custom-object tabs |
| Apps | `Field_Service_Console` (primary console for dispatch/back office) |

---

## 3. Gap report — UI issues reported by user (2026-06-01 screenshots)

| # | Issue | Root cause (from metadata) | Recommendation | Approval needed |
|---|---|---|---|---|
| 1 | Field Service Console **home page blank** | `HomePage.flexipage-meta.xml` has no components placed; `lovingOpsLinks` LWC exists but is on no FlexiPage. | Create new `LOVING_Field_Service_Home` AppPage FlexiPage with `lovingOpsLinks` + Today's Service Appointments + WO pipeline chart; assign as FS Console home tab. | No (additive only); however App→home assignment is Setup UI (browser) |
| 2 | Scheduling Console appears empty | Tab → `Scheduling_Console_Home` FlexiPage **has** `lovingSchedulingConsole` LWC placed. Empty render likely runtime issue: empty data, Apex permission, or wired query returning 0 rows. Needs browser repro to diagnose. | Inspect `SchedulingConsoleController.getDivisions/getAppointments` behavior with current user permissions; verify CMT `LOVING_Division__mdt` records exist in prod (deployed earlier this session). | No to investigate |
| 3 | Quick action modals open **blank** (Update Material, Add Punch List, etc.) | Likely screen-flow-backed quick actions where the referenced flow is broken / Draft / unreachable. The 3 takeoff flows deleted earlier this session were exactly this pattern. | Enumerate WO quick actions, map each → flow/LWC, identify orphans. | No to investigate |
| 4 | "AI Summarize Notes" routes to Activities instead of Agentforce | Action is wired to standard Activity timeline, not an Agentforce prompt template. | Check if Agentforce / Einstein GPT is licensed in `loving-prod` (Section 8 brief gap). If yes, replace action target with prompt-template invocation. If no, build prompt template + invocable Apex stub and document enablement step. | Yes — Agentforce licensing/enablement is Setup |
| 5 | Section header color bands don't extend over the section name (e.g., "Punch List") | CSS in the relevant LWC (likely `workOrderPunchList` or section wrapper) — color block ends before label. | CSS-only fix once the component is identified (Punch List section). | No |
| 6 | Section labels include the word "Header" (e.g., "Work Order Header") | FlexiPage `<itemInstances><componentInstanceProperties>` labels in `LOVING_Work_Order_Record_Page.flexipage`. | Rename labels — strip "Header". | No |
| 7 | Components don't fill full width — empty right rail | FlexiPage layout uses a template that exposes regions the page doesn't populate, OR LWC max-width CSS is constraining. | Audit each FlexiPage's `<template>`; default to a 1-region full-width template for pages that don't need a right rail; expand LWC widths to 100%. | No |

---

## 4. Earlier-session findings (carried forward)

These were completed earlier in this session and are committed to the branch:

- `workOrderPhotoGallery` — Upload Photo CTA added (modal + `lightning-file-upload`, posts to `WorkOrderPhotoController.createPhotoRecord`, refreshes wired data via `refreshApex`).
- `lovingOpsLinks` — WEX URL corrected to `login.wextelematics.com` (was a marketing page); WEX + Rippling URLs moved off hardcoded JS and into `LOVING_External_Link__mdt` CMT records. Weather + Maps still territory-aware.
- `lovingSchedulingConsole` — `ALL_DIVISIONS` / `DIV_LABELS` / `TERRITORY_COORDS` hardcoded arrays replaced with `LOVING_Division__mdt` CMT (6 records: All, Charlotte, Triad, Greenville, Columbia, Asheville).
- 3 broken/draft flows deleted (`LOVING_Takeoff_Approved`, `LOVING_Takeoff_Approved_Create_WOs`, `LOVING_Takeoff_To_WO_Creation`).
- Still in-org (not in repo, not yet deleted): `Create Builder Account Cascade` (InvalidDraft), `Weather NWS Classification` (InvalidDraft) — to be deleted via Setup or Tooling API.

---

## 5. Field Service / FSL readiness (read-only check)

Not fully verified in this run — requires browser/Setup inspection. Listed in punch list for morning verification.

| Element | Verified? | How to verify |
|---|---|---|
| Field Service enabled | Implied by `FSL__FieldService` tab in app | Setup → Field Service Settings |
| Service Territories | Not directly verified | SOQL `SELECT Id, Name, IsActive FROM ServiceTerritory` |
| Operating Hours | Not verified | SOQL `SELECT Id, Name FROM OperatingHours` |
| Service Resources | Not verified | SOQL `SELECT Id, Name, IsActive FROM ServiceResource` |
| Scheduling Policies | Not verified | Setup → Field Service Settings → Scheduling |
| Work Rules | Not verified | Setup → Field Service Settings |
| Dispatcher Console | App `Field_Service_Console` deployed | Open the app as a dispatcher user |
| Field Service Mobile | Not in scope of this session | — |

---

## 6. Agentforce / Einstein

- Not verified whether licenses are enabled in `loving-prod`.
- AI Summarize Notes button (issue #4) currently points at standard Activity timeline, not an Agentforce action.
- **Recommendation:** In the morning, check Setup → Einstein Generative AI → enablement. If enabled, build the AI Summarize prompt template and re-wire the action. If not, this is a licensing/enablement blocker for the brief's Section 8.

---

## 7. Test class debt (carried from earlier session)

- `SchedulingConsoleControllerTest.cls` uses `SeeAllData=true` in places — known anti-pattern, flagged earlier but not yet refactored.
- Action: refactor to use `@TestSetup` data builders. Not done in this session — added to punch list.

---

## 8. Items requiring approval (Section 5 of brief)

See `docs/approval-log.md`.
