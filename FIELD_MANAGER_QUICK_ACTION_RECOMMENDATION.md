# Field Manager Quick Action Launch Recommendation

**Audit Date:** 2026-06-05  
**Auditor:** Claude Code  
**Scope:** LOVING FM app (React workspace + Salesforce FSL metadata), Foreman mobile, production org `dispatch`

---

## TL;DR

| Question | Answer |
|---|---|
| Are Field Manager quick actions field-ready? | **PARTIAL** — React workspace has 15 actions, all save to SF. Salesforce Lightning has 0 FM quick actions (only 5 Foreman actions). |
| Are New Lead and New Opportunity removed from FM view? | **NO** — They appear in `odlConsoleHome` and `homeownerAccountCommandCenter` LWCs accessible from Sales tabs. Not in FM React app but visible if FM ever opens those pages. |
| Can FM create a quote request for Customer Success? | **NO** — `UMB_Quote_Request__c` exists for add-on scopes but no FM-facing flow or action creates it. No routing to CS. |
| Can FM log an issue and route it to Finished Job, Warranty Job, or Quote Request? | **PARTIAL** — FM can flag issues in React app (routes to Schedule_Issue__c). Finished Job creates a child WorkOrder with `Is_Finished_Job__c = true`. `Warranty_Record__c` exists but no FM flow creates it. |
| Does Measure save to the Lot/Site record? | **PARTIAL** — Measurements save to WorkOrder.Takeoff_*__c fields (not clipboard). `Lot__c` has `Takeoff_Approved_Date__c` only — no Measured_Sqft, Slope, Drainage fields on Lot__c. |
| Is the login experience clean and mobile-ready? | **NO for Lightning.** React app: yes — polished workspace UI. Salesforce Lightning FM login: shows generic SF home, Sales Cloud Mobile tabs include Lead and Opportunity. |
| Biggest risk | Field Manager and Foreman are different roles in this org. Metadata serves Foreman; React app serves FM. These are never unified. FM in Lightning sees sales clutter. |
| Recommended launch decision | **PILOT ONLY** — React app is operationally ready for FM workflow. Salesforce Lightning FM experience is not clean, not safe, and missing FM-specific actions. Do not fully launch until (1) FM Lightning page is deployed with clean quick actions, (2) New Lead/Opportunity are hidden from FM profile, (3) Quote Request and Warranty Job routing are wired. |

---

## Architecture Clarification

There are **two different roles** in this org:

| Role | System | Actions Available | Profile |
|---|---|---|---|
| **Field Manager (FM)** | React workspace (`FM__c` on WorkOrder) | 15 domain actions via REST API | Reviews, gates, approves — does NOT do physical field work |
| **Foreman** | Salesforce FSL mobile app | 5 quick actions (Arrival, Closeout, EOD, Flag, PreShift) | Crew leader who physically executes jobs |

The Foreman experience in Salesforce mobile is separate from and more mature than the FM experience. This document covers the **Field Manager** experience.

---

## Recommended Quick Actions

| Action | Add/Keep/Hide | User | Object Created/Updated | Route To | Launch Priority |
|---|---|---|---|---|---|
| Complete Takeoff | **ADD** — build FM Takeoff flow | Field Manager | WorkOrder (Takeoff_*__c fields) | Ready to Schedule queue | P0 |
| Log Issue | **ADD** — build guided router flow | Field Manager | Schedule_Issue__c / child WorkOrder / Warranty_Record__c | Type-based routing | P0 |
| Create Quote Request | **ADD** — build FM Quote Request flow | Field Manager | UMB_Quote_Request__c or Change_Order__c | Customer Success | P0 |
| Upload Site Photos | **ADD** — wire ContentVersion action | Field Manager | ContentVersion → linked to WO/Lot | Photo gallery | P0 |
| Mark Site Ready | **ADD** — build Site Readiness flow | Field Manager | WorkOrder (Site_Ready__c, Site_Readiness_Status__c) | Scheduling queue | P0 |
| Flag Site Not Ready | **ADD** — build Site Blocker flow | Field Manager | WorkOrder + Schedule_Issue__c | Scheduling Manager | P0 |
| Complete QI | **ADD** — build FM QI flow | Field Manager | WorkOrder (QI_*__c fields) | Closeout queue if pass | P1 |
| Create Finished Job | **ADD** — build child WO flow | Field Manager | Child WorkOrder (Is_Finished_Job__c = true) | Scheduling queue | P1 |
| Create Warranty Job | **ADD** — build Warranty flow | Field Manager | Warranty_Record__c | Customer Success | P1 |
| Request Reschedule | **ADD** — build Reschedule Request flow | Field Manager | Schedule_Issue__c / Task | Scheduling Manager | P1 |
| 2 PM Crew Health Check | **ADD** — build Health Check flow | Field Manager | WorkOrder (Health_Check_*__c fields) | FM review / auto-escalate | P1 |
| Approve Closeout | **ADD** — build Closeout Approval flow | Field Manager | WorkOrder (Closeout_*__c fields) | Invoicing / CS handoff | P2 |
| Log Arrival (Foreman) | **KEEP** — already in metadata | Foreman | WorkOrder (Arrived_At__c) | N/A | KEEP |
| Pre-Shift Check (Foreman) | **KEEP** — already in metadata | Foreman | Morning_Vehicle_Checklist__c | N/A | KEEP |
| Flag Issue (Foreman) | **KEEP** — already in metadata | Foreman | Schedule_Issue__c | FM review | KEEP |
| Submit Closeout (Foreman) | **KEEP** — already in metadata | Foreman | WorkOrder → Pending Closeout | FM queue | KEEP |
| EOD Summary (Foreman) | **KEEP** — already in metadata | Foreman | Rippling_Time_Entry__c | N/A | KEEP |
| New Lead | **HIDE** from FM profile | N/A | N/A | N/A | HIDE |
| New Opportunity | **HIDE** from FM profile | N/A | N/A | N/A | HIDE |
| New Campaign | **HIDE** from FM profile | N/A | N/A | N/A | HIDE |

---

## Actions To Hide

| Action | Why Hidden | Where To Hide | Risk If Left Visible |
|---|---|---|---|
| New Lead | FM is field execution; leads are sales process | odlConsoleHome LWC, homeownerAccountCommandCenter LWC, FM app page, FM permission set tab visibility | FM accidentally creates junk leads from job sites |
| New Opportunity | FM must not initiate revenue-cloud deals | odlConsoleHome LWC, homeownerAccountCommandCenter LWC, FM app page | FM creates unqualified opps that poison pipeline |
| New Campaign | No field use case | Sales tab / FM page | None significant — cosmetic clutter |
| Edit GP / Edit Final Pricing | FM must not set margin | WorkOrder page layout field-level security on GP_Status__c, Gross_Profit__c, Revenue_Amount__c | FM changes margin, Finance reports wrong numbers |
| Create Invoice | FM must not bill | WorkOrder field + flow guard | Premature invoice, billing error |
| Bill Parent Account | Guardrail in API contract (confirmed) | React app guard + Apex server-side check | Major billing control failure |
| Mass Update Actions | No field use case | Profile/permission set | Accidental bulk data change |
| Convert Lead | No field use case | Profile / lead object perm | FM converts a lead incorrectly |
| Delete Record | FM should not delete | Profile — remove Modify All, remove Delete on WorkOrder/Case | Data loss |

---

## Issue Routing

| Field Issue | Correct System Outcome | Object | Owner | Required Fields |
|---|---|---|---|---|
| Original scope incomplete | Create child Work Order as Finished Job | WorkOrder (Is_Finished_Job__c=true, Parent_Work_Order__c) | Scheduling Manager | Reason, Scope Description, Schedule Need |
| Warranty concern | Create Warranty_Record__c + route to CS | Warranty_Record__c | Customer Success | Category, Original WO, Photos, Severity |
| Customer complaint | Create Case (type: Customer Complaint) | Case | Customer Success | Account, Contact, Description |
| Builder punch item | Create Change_Order__c + Case if builder-facing | Change_Order__c | Customer Success | Builder Account, Lot, Scope |
| New requested scope | Create UMB_Quote_Request__c or Change_Order__c | Change_Order__c preferred | Customer Success / Estimating | Scope, Photos, Quantities, Billable recommendation |
| Quantity variance | Create Change_Order__c with variance documentation | Change_Order__c | Customer Success | WO, Lot, PO Qty vs. Measured Qty |
| Drainage issue | Create Schedule_Issue__c + Quote Request if billable | Schedule_Issue__c | Scheduling Manager | Photos, Severity, Billable flag |
| Waterline / utility conflict | Create Schedule_Issue__c + 811 flag | Schedule_Issue__c | Scheduling Manager + Safety | Photos, Location, 811 status |
| Site not ready | Update WorkOrder Site_Ready__c=false + Schedule_Issue__c | WorkOrder + Schedule_Issue__c | Scheduling Manager | Reason, Photos, Blocker type |
| Crew damage | Create Schedule_Issue__c (Internal type) + notify manager | Schedule_Issue__c | FM + Regional Manager | Photos, Description, Crew ID |
| Missing material | Create Schedule_Issue__c (Material type) | Schedule_Issue__c | Inventory / Scheduling | Material, Qty needed, WO |
| Safety issue | Create Schedule_Issue__c (Safety type) + escalate | Schedule_Issue__c | FM + Safety Officer | Photos, Description, Severity=High |
| Access issue | Update WorkOrder + Create Schedule_Issue__c | WorkOrder + Schedule_Issue__c | Scheduling Manager | Builder contact, Access type |

---

## Quote Request Flow

| Step | Field Manager Action | System Action | Customer Success Action |
|---|---|---|---|
| 1 | FM clicks "Create Quote Request" from WorkOrder | Open FM Quote Request screen | — |
| 2 | FM selects: Homeowner / Builder / Warranty / Internal | Prefill Account, Contact, Lot from WO | — |
| 3 | FM enters scope, quantities, photos, notes | Validate required fields | — |
| 4 | FM submits | Create UMB_Quote_Request__c (Status: Field Request) | CS receives new record in queue |
| 5 | — | Notify CS via Task + Chatter | CS reviews scope and assigns to Estimating |
| 6 | FM receives status update | Update UMB_Quote_Request__c Status | CS prices, routes for approval |
| 7 | FM may add notes only | No price edit allowed | CS sends final quote to customer |

**FM cannot set price, GP, discount, or mark Approved at any step.**

---

## Warranty / Finished Job Decision Logic

| Condition | Create Finished Job | Create Warranty Job | Create Quote Request | Notes |
|---|---|---|---|---|
| LOVING missed original contracted scope | ✅ Yes | No | No | No charge; FM owns follow-through |
| QI failed — rework required | ✅ Yes | No | No | Block closeout until FJ resolved |
| Post-completion plant warranty | No | ✅ Yes | Maybe if billable | Route to CS; coverage decision required |
| Sod failure within warranty period | No | ✅ Yes | No | Warranty_Record__c, category: Sod issue |
| Customer added new scope request | No | No | ✅ Yes | UMB_Quote_Request__c; FM cannot price |
| Builder punch item (original scope) | ✅ Maybe | No | Maybe | Depends on whether LOVING owes it |
| Builder punch item (new/change request) | No | No | ✅ Yes | Change_Order__c |
| Drainage issue — LOVING caused | ✅ Yes | Maybe | Maybe if billable | Site readiness miss → Finished Job |
| Drainage issue — pre-existing / site condition | No | No | ✅ Yes | Quote Request to customer |
| Material quantity variance (LOVING short) | ✅ Yes | No | No | Finish the scope at no charge |
| Material quantity variance (over-delivered) | No | No | ✅ Maybe | Change Order to recover cost |

---

## UI / UX Notes

| Area | Recommendation | Reason |
|---|---|---|
| FM login screen | Use `lovingFieldManagerWorkspace` LWC (or React app wrapper) with quick action cards | React workspace is already clean and polished |
| Card order | Start/Readiness → Field Proof → Exceptions → Money/Scope → Closeout | Matches FM's daily workflow timeline |
| "New Lead" / "New Opportunity" | Remove buttons from `odlConsoleHome.html` lines 34, 38 for FM profile; hide via app/permission | These are Sales LWC components exposed to FM accidentally |
| Tab navigation | FM app should not inherit Sales Cloud Mobile tabs (Lead, Opportunity, Campaign) | Wrong context for field execution |
| Quick action labels | Use plain operational English: "Flag Site Not Ready" not "Create Site_Ready__c Record = False" | FM at 5 PM on a job site needs clarity |
| Mobile spacing | Existing React workspace is mobile-first. Lightning FM page needs min 44px tap targets | Confirmed by design review of seed data UI |
| Header | No double headers. React app has clean SF-nav-less rendering when deployed as an AppPage | See Schedule Console deploy pattern already established |
| Error messages | Friendly field-facing: "Add a scope note before submitting. CS needs enough detail to price this." | Not Salesforce field validation error codes |
| Photos | Category picker before upload; require at least one for Takeoff, QI, Finished Job, Warranty | ContentVersion `Description` field maps to category |
| Offline | FSL offline should be configured for Field_Checklist__c and WorkOrder updates; React app has field-first pattern | Field managers work on job sites with weak signal |

---

## Testing Results

| Test | Result | Evidence | Fix Needed |
|---|---|---|---|
| FM logs in — sees command center | **FAIL** | Lightning home shows generic SF home; React app shows workspace | Deploy FM Lightning App Page |
| FM does not see New Lead | **FAIL** | `odlConsoleHome.html` line 38: New Lead button; Sales Cloud Mobile has Lead tab | Remove from FM app/profile |
| FM does not see New Opportunity | **FAIL** | `odlConsoleHome.html` line 34 + `odlHomeDashboardWorkspace.html` | Remove from FM app/profile |
| FM clicks Complete Takeoff | **PARTIAL** | React app: validateTakeoff() works, saves to WorkOrder. Lightning: no action exists | Build FM Takeoff quick action |
| Measurement saves to Lot/Site | **PARTIAL** | Saves to WorkOrder.Takeoff_*__c fields (confirmed). Lot__c has no measurement fields | Add measurement fields to Lot__c OR accept WorkOrder as measurement owner |
| FM creates Quote Request | **FAIL** | UMB_Quote_Request__c exists but no FM flow creates it | Build Quote Request flow |
| Quote routes to CS | **FAIL** | No routing logic exists | Build CS routing + notification |
| Quote does not become final quote | **DESIGN OK** | UMB_Quote_Request__c has no pricing fields visible to FM | Confirm FM cannot set price via FLS |
| Log Issue routes Finished Job | **PARTIAL** | React: createFinishedJob() creates child WO. Lightning: no guided router | Build guided issue router flow |
| Log Issue routes Warranty | **FAIL** | React: routes to Site Visit decision only. Lightning: Warranty_Record__c exists but no flow | Build Warranty Job flow |
| Finished Job links to parent WO | **PASS** | WorkOrder.Is_Finished_Job__c + Finish_Job_*__c fields confirmed | No fix needed |
| Photos save as SF Files | **PASS** | salesforceApiClient.ts: ContentVersion POST confirmed | No fix needed |
| QI blocks closeout if failed | **PASS** | React: submitQiPass() checks score ≥7; approveCloseout() requires QI passed | Confirm Apex/flow enforces same gate |
| Closeout cannot approve with blockers | **PASS** | React: approveCloseout() validates all gates | Confirm server-side validation in Apex |
| Sales users retain actions | **PASS** | odlConsoleHome, homeownerAccountCommandCenter retain Lead/Opportunity actions | Do not change Sales LWCs globally |
| FM cannot edit final pricing/GP | **PASS in React** | API contract confirms: FM cannot edit GP/billing. Apex guard confirmed | Verify FLS on GP_Status__c, Revenue_Amount__c for FM profile |
| CS receives routed records | **FAIL** | No routing exists currently | Build routing with Task + Chatter notification |
| Mobile spacing works | **PASS (React)** | React workspace is mobile-first, responsive | Test on iPad once Lightning FM page deployed |
| Offline behavior | **UNKNOWN** | FSL offline config not audited in this scope | Audit FSL mobile config separately |

---

## Final Recommendation

**Status: PILOT ONLY — Not ready for full FM go-live in Salesforce Lightning**

### What works right now
- The React Field Manager workspace app is operationally solid. 15 domain actions save real records to Salesforce. Measurements are not clipboard-only. QI, Finished Jobs, and closeout gates are enforced.
- The Foreman mobile experience (5 quick actions + 5 flows) is deployed and functional.
- `Warranty_Record__c`, `Change_Order__c`, `UMB_Quote_Request__c`, `Schedule_Issue__c` all exist and can be wired.

### What is not ready
1. **FM Salesforce Lightning experience is empty.** There are 0 FM quick actions in Lightning. The Foreman quick actions exist but serve a different role.
2. **New Lead and New Opportunity are visible** in Sales LWC components that FM profiles can access.
3. **Quote Request has no FM flow.** `UMB_Quote_Request__c` exists but no FM-facing screen creates it or routes it to CS.
4. **Warranty Job has no FM flow.** `Warranty_Record__c` exists but no FM creates it from the field.
5. **Lot__c has no measurement fields.** Measurements land on WorkOrder, not Lot. This is acceptable architecturally but should be a known decision.
6. **No FM-specific Lightning App.** The `Loving_Foreman` app is marked "Prototype / Internal Review only. Not accepted as the production LOVING field app."

### Recommended next steps
1. Build 12 FM Lightning flows (Takeoff, Log Issue, Quote Request, Warranty, Finished Job, Site Ready, Site Not Ready, Photos, QI, Reschedule, Health Check, Closeout)
2. Create `LOVING_Field_Manager` Lightning App with clean 8-tab nav (Schedule Console first)
3. Hide New Lead / New Opportunity from FM app page and FM profile tab visibility
4. Add FLS restrictions on GP/pricing fields for FM profile
5. Build CS routing on Quote Request and Warranty Job creation (Task + Chatter)
6. Deploy FM Lightning quick action cards as an AppPage using the established LOVING card design system
