# Field Manager Quick Action Audit — Full Recommendation

**Audit Date:** 2026-06-04  
**Auditor:** Claude Code  
**Scope:** LOVING Field Manager app (React/Vite/Capacitor) + Salesforce org metadata  
**Branch:** `claude/magical-carson-6PAuZ`

---

## TL;DR

The FM app is structurally sound. Real records are created, real gates block closeout, and pricing is locked out. However, **three critical gaps block production readiness:**

1. `Quote_Request__c` does not exist in the org — the entire quote request flow is unbuilt at the data layer.
2. There are zero FM-facing Salesforce Quick Actions — only 5 Foreman actions exist. FM has no native Salesforce action path.
3. Warranty job creation from the FM app is a TypeScript type declaration only — no `createWarrantyJob()` action and no Salesforce object or workflow backs it.

If any of these gaps remain at launch, FM workflow will route to workarounds (clipboard, phone call, informal email) within one week on the job.

---

## What IS Working — Do Not Touch

| Feature | Status | Evidence |
|---|---|---|
| No Lead/Opportunity in FM nav | Clean | No such tabs in App.tsx; Permission set `LOVING_Field_Manager_App_User` does not include those objects |
| Takeoff measurements save to WorkOrder | Working | `updateTakeoffVerifiedAmount()` + `validateTakeoff()` in domainActions.ts persist to WorkOrder fields via Salesforce API |
| Real Finished Job creation | Working | `createFinishedJob()` creates a child `Finish_Job__c` record with `Parent_Work_Order__c` lookup. `Is_Finished_Job__c`, `Finish_Job_Required__c`, `Finish_Job_Reason__c` all exist on WorkOrder |
| QI scoring with real threshold | Working | `submitQiPass()` enforces threshold 7.0; below 7.0 triggers hard hold on closeout and invoice |
| Photo proof by category | Working | `uploadPhoto()` + `acceptPhotoPackage()` require minimum 4 accepted categories before QI can proceed |
| FM cannot edit pricing or GP | Working | `Revenue_Amount__c`, `Cost_Amount__c`, `Gross_Profit__c`, `Gross_Margin_Pct__c` are read-only via `LOVING_Field_Manager_App_User` permission set |
| Approve Closeout with gates | Working | `approveCloseout()` is blocked unless all gateStatus items are done AND QI status is Passed |
| Request Reschedule | Working | `requestReschedule()` logs to Salesforce and notifies Scheduling Manager |
| Stage-aware UI | Working | `MobileTab` in App.tsx renders different views per `stageIndex` |

---

## Recommended Quick Actions — FM-Facing

The following actions should be built as Salesforce Quick Actions on `WorkOrder` object with prefix `WorkOrder.LOVING_FM_*`:

| Action Name | Object | Trigger | Outcome | Priority |
|---|---|---|---|---|
| `LOVING_FM_Validate_Takeoff` | WorkOrder | FM taps "Validate Takeoff" | Sets `Takeoff_Complete__c = true`, `Takeoff_FM__c = FM user`, `Takeoff_Date__c = today` on WorkOrder | P0 — Launch blocker |
| `LOVING_FM_Mark_Site_Ready` | WorkOrder + Site_Readiness__c | FM taps "Mark Site Ready" | Sets `Site_Readiness_Status__c = 'Ready'`; creates or updates `Site_Readiness__c` record; notifies Scheduling | P0 — Launch blocker |
| `LOVING_FM_Flag_Site_Not_Ready` | WorkOrder + Site_Readiness__c | FM taps "Flag Site Not Ready" | Sets `Site_Readiness_Status__c = 'Not Ready'`; populates `Site_Not_Ready_Reason__c`; creates `Site_Readiness__c` record | P0 — Launch blocker |
| `LOVING_FM_Request_Quote` | Quote_Request__c (new object) OR Case | FM taps "Request Quote" | Creates `Quote_Request__c` child record linked to WorkOrder; notifies CSM | P0 — Launch blocker |
| `LOVING_FM_Create_Finished_Job` | Finish_Job__c | FM taps "Create Finished Job" | Creates `Finish_Job__c` record with `Parent_Work_Order__c`, reason, scope, FJ date | P0 — Exists in app, needs SF-side action |
| `LOVING_FM_Create_Warranty_Job` | WorkOrder (new child) | FM taps "Create Warranty Job" | Creates new WorkOrder child with `Work_Order_Type__c = 'Warranty'` linked to original lot | P1 — Pre-launch |
| `LOVING_FM_Log_Field_Issue` | Schedule_Issue__c | FM taps "Log Issue" | Creates `Schedule_Issue__c` record; routes to correct owner based on issue type | P1 — Pre-launch |
| `LOVING_FM_Approve_QI` | QI_Inspection__c | FM taps "Approve QI" | Sets `QI_Inspection__c.Status__c = 'Approved'`, `QI_FM__c = FM user`, `QI_Date__c = today`, `QI_Score__c` | P0 — Launch blocker |

---

## Actions to Remove or Hide from FM View

The FM role is review-and-approval only. The following actions are **Foreman-only** and must not appear in the FM app navigation or action sheet:

| Action | Reason to Hide from FM |
|---|---|
| `WorkOrder.LOVING_Foreman_Arrival` | FM does not check in at a job site as crew |
| `WorkOrder.LOVING_Foreman_PreShift` | Pre-shift checklist is foreman/crew responsibility |
| `WorkOrder.LOVING_Foreman_EOD` | End-of-day reporting is foreman responsibility |
| `WorkOrder.LOVING_Foreman_Flag` | Field issue flagging flows through FM Log Issue action |
| `WorkOrder.LOVING_Foreman_Closeout` | Foreman submits; FM approves — these are different actions |
| New Lead | Must not exist in any FM view |
| New Opportunity | Must not exist in any FM view |
| New Contact (on unrelated record) | Not relevant to FM workflow |

---

## Issue Routing — Log Issue Action

When a FM logs a field issue, the routing logic must be:

| Issue Type | Routes To | Object Created | Required Fields |
|---|---|---|---|
| Scheduling conflict | Scheduling Manager | `Schedule_Issue__c` | Issue type, date needed, notes |
| Site not ready | Scheduling Manager + Builder Regional | `Site_Readiness__c` + WorkOrder flag | Reason, photos required |
| Scope outside PO | CSM / Inside Sales | `Quote_Request__c` | Scope description, photos, lot number |
| Warranty claim | FM (self) creates Warranty Job | Child WorkOrder (`Work_Order_Type__c = 'Warranty'`) | Original WO ID, scope, decision |
| Aqua issue | Aqua Tech + FM | `Aqua_Inventory__c` update | Issue type, inventory affected, priority |
| Red flag / safety | Division Manager | WorkOrder `Red_Flag_Notes__c` + `Red_Flag_Timestamp__c` | Notes, timestamp |

---

## Quote Request Flow

`Quote_Request__c` **does not exist** in the org today. Two options:

**Option A — Create `Quote_Request__c` custom object (Recommended)**
- Child of WorkOrder (lookup: `Work_Order__c`)
- Fields: `Scope_Description__c` (Long Text), `Requested_By__c` (User lookup), `Status__c` (New / Sent to CSM / Approved / Rejected), `Quote_Amount__c` (Currency, read-only to FM), `Builder_Approval__c` (Checkbox), `Photos_Attached__c` (Number)
- Owner defaults to CSM assigned to the Division account
- FM can create and view; FM cannot edit `Quote_Amount__c` or `Builder_Approval__c`

**Option B — Use Case object with RecordType "Quote Request"**
- Lower implementation cost; leverages existing Case routing
- Loses custom field fidelity; mixes with support case queue

**Non-negotiable rule:** FM may not finalize pricing or approve a quote. The `Quote_Request__c.Quote_Amount__c` field must be read-only to the `LOVING_Field_Manager_App_User` permission set. If an FM can edit the final price, the workflow is not safe.

---

## Warranty / Finished Job Decision Logic

The FM app TypeScript types already define a `SiteVisitRecord` with `purpose: "Warranty Determination" | "Finished Job Determination" | "Proposal Scope"`, but **no `createWarrantyJob()` action exists in domainActions.ts** and no Salesforce-side workflow backs warranty decisions.

Required logic:

```
FM visits site →
  FM records decision in Site Visit checklist
  IF decision = "Warranty":
    Create child WorkOrder with Work_Order_Type__c = 'Warranty'
    Link to original WorkOrder (Parent_Work_Order__c)
    Set Is_Finished_Job__c = false on original
    Notify Division Manager
  IF decision = "Finished Job":
    createFinishedJob() → Finish_Job__c record (already built)
    Set Finish_Job_Required__c = true on original WorkOrder
    Block invoice until Finish_Job__c is closed
  IF decision = "Proposal Needed":
    createQuoteRequest() → Quote_Request__c record
    Route to CSM
```

Warranty WorkOrder must inherit: `Lot__c`, `Builder_PO__c` lookup, `Community__c`, `Foreman__c`, and `Aqua_Community__c` from parent. `Work_Order_Type__c` must be set to `'Warranty'` and must be validated on the Salesforce side (not just in the app) so bulk loads or API updates cannot bypass it.

---

## UI Notes

- **Command tab** — "Next Best Actions" should drive to FM-specific actions, not Foreman actions
- **Takeoff tab** — "Complete Takeoff" button must call `LOVING_FM_Validate_Takeoff` quick action (real SF save), not just local state update
- **WorkOrder tab** — Headcount, sod sqft, and schedule controls displayed correctly; FM cannot edit crew hours or line item prices
- **QI/Closeout tab** — "Approve Closeout" gate correctly blocked by QI Passed + all gates done. Threshold 7.0 is correct.
- **Mobile tab** — Stage-aware rendering works. Default job (lot118) shows QI stage. Lot 204 shows takeoff stage. Working as designed.
- **No pricing fields exposed** — `Revenue_Amount__c`, `Cost_Amount__c`, `Gross_Profit__c`, `Gross_Margin_Pct__c` are not in any FM-facing form. Confirmed clean.

---

## Test Results Summary

See `FIELD_MANAGER_LOGIN_SCREEN_TEST_RESULTS.md` for full test scenario results.

| Category | Total | Pass | Fail | Blocked |
|---|---|---|---|---|
| Authentication & Access | 4 | 4 | 0 | 0 |
| Navigation & Role Separation | 5 | 5 | 0 | 0 |
| Takeoff Workflow | 5 | 3 | 1 | 1 |
| QI & Closeout | 4 | 3 | 0 | 1 |
| Issue Routing | 3 | 0 | 2 | 1 |
| Quote Request | 3 | 0 | 3 | 0 |
| **TOTAL** | **24** | **15** | **6** | **3** |

---

## Final Recommendation

**Do not launch without:**

1. `Quote_Request__c` object built and deployed (or Case RecordType configured) — the flow does not exist at all today
2. `LOVING_FM_Validate_Takeoff` quick action deployed and wired to WorkOrder fields — app-side `validateTakeoff()` must persist to Salesforce, not just local state
3. `LOVING_FM_Approve_QI` quick action deployed — `QI_Inspection__c.Status__c`, `QI_FM__c`, `QI_Score__c` must be set on approval
4. `LOVING_FM_Mark_Site_Ready` and `LOVING_FM_Flag_Site_Not_Ready` quick actions deployed — `Site_Readiness__c` records must be created in Salesforce

**Can launch without (P1, add within 30 days):**

- Warranty job creation flow
- `Schedule_Issue__c` FM Log Issue action
- Full Microsoft 365 calendar sync (integration is deployed but needs configuration)

**Already clean at launch:**

- No Lead/Opportunity in FM
- No clipboard-only measurement workflow
- FM cannot finalize quotes or edit pricing
- Finished Job creation is real
- QI threshold gates are real
