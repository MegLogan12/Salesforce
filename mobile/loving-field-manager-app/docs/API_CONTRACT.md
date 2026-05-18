# API Contract: LOVING Field Manager Workspace

## TL;DR

The React app must not know raw Salesforce object details. Salesforce should return a clean workspace DTO that matches `src/types.ts`. This keeps the desktop page, iOS app, and future Salesforce page behavior consistent.

## Base endpoints

| Method | Endpoint | Purpose |
|---|---|---|
| GET | `/services/apexrest/loving/field-manager/workspace` | Load current FM workspace. |
| PUT | `/services/apexrest/loving/field-manager/workspace` | Demo/debug save only. Avoid in production unless controlled. |
| POST | `/services/apexrest/loving/field-manager/jobs/{jobId}/photos` | Upload or register a photo proof category. |
| POST | `/services/apexrest/loving/field-manager/jobs/{jobId}/qi` | Submit QI scores and notes. |
| POST | `/services/apexrest/loving/field-manager/jobs/{jobId}/return` | Return work to Foreman, Aqua Tech, CSM, or Scheduler. |
| POST | `/services/apexrest/loving/field-manager/jobs/{jobId}/finished-job` | Create Finished Job child Work Order. |
| POST | `/services/apexrest/loving/field-manager/jobs/{jobId}/aqua-repair` | Dispatch Aqua repair or update same-day ticket. |
| POST | `/services/apexrest/loving/field-manager/jobs/{jobId}/reschedule-request` | Create schedule change request for Scheduling Manager. |
| POST | `/services/apexrest/loving/field-manager/jobs/{jobId}/closeout-approval` | Approve closeout if gates pass. |

## Workspace DTO

The API response must match this top-level shape:

```json
{
  "currentUser": { "id": "005...", "name": "Jordan Ellis", "role": "Field Manager" },
  "selectedJobId": "a0W...",
  "workQueue": [{ "jobId": "a0W...", "priority": 1 }],
  "priorities": [],
  "jobs": [],
  "forms": {}
}
```

Use `src/types.ts` as the formal TypeScript contract.

## Salesforce object mapping

| DTO Area | Salesforce Source | Rule |
|---|---|---|
| `currentUser` | User, Employee__c if applicable | Must identify FM and permissions. |
| `workQueue` | Work_Order__c, Aqua tickets, QI_Inspection__c, Schedule_Issue__c | Sort by real priority, not UI order. |
| `breadcrumbs` | Account, Community__c, Lot__c, Work_Order__c | Parent displayed only as roll-up. |
| `meta` | Lot__c, Community__c, Work_Order__c, Employee__c, ServiceTerritory | Display selected job context. |
| `kpis` | Work_Order__c, QI_Inspection__c, Invoice__c, Aqua tickets | Values must be calculated server-side where possible. |
| `stageIndex` | Work_Order__c.Status__c mapping | Use consistent lifecycle mapping. |
| `takeoff` | Takeoff__c, Takeoff_Task__c | Include 811, site readiness, photos, package comparison. |
| `workOrder` | Work_Order__c, Work_Order_Line_Item__c, ServiceAppointment | Include schedule, crew, route, status, line items. |
| `aqua` | Aqua_Install_Ticket__c, Aqua_Check_Ticket__c, Aqua_Pickup_Ticket__c | Include install, checks, closeout gates. |
| `photos` | Photo__c, ContentDocumentLink | Must include category, caption, uploaded by, uploaded at, URL. |
| `qi` | QI_Inspection__c | Include score categories and outcome. |
| `invoicePreview` | Invoice__c or pending invoice calculation | Must bill Builder Division, not Parent. |
| `activity` | Work_Order_Note__c, Chatter, audit events | Every mutation logs an event. |

## Action payloads

### Submit QI

```json
{
  "scores": {
    "Sod Install": 9,
    "Plant Install": 8,
    "Cleanup": 8,
    "Aqua": 9
  },
  "notes": "Scope complete. Photos accepted."
}
```

Server must:

1. Validate photo categories.
2. Calculate overall score.
3. Create or update `QI_Inspection__c`.
4. Set Work Order QI fields.
5. Return updated workspace DTO or updated job DTO.

### Return Work

```json
{
  "owner": "Foreman",
  "reason": "Missing required photo",
  "instructions": "Upload after photo showing final clean area."
}
```

Server must:

1. Create task or field-facing note.
2. Block closeout.
3. Increment NFI count when applicable.
4. Return updated job DTO.

### Create Finished Job

```json
{
  "reason": "Incomplete Scope",
  "scope": "Return to complete pine straw touch-up and left-side edge cleanup.",
  "scheduleNeed": "Return tomorrow"
}
```

Server must:

1. Create child Work Order.
2. Set parent work order lookup.
3. Set no-charge billing type.
4. Copy incomplete line items when applicable.
5. Update FM scorecard path.
6. Return updated job DTO.

### Dispatch Aqua Repair

```json
{
  "issueType": "Dry Spot",
  "priority": "Same-Day",
  "tech": "Marcos Rivera",
  "inventory": "2 heads, 4 flags",
  "notes": "Verify coverage and replace head if needed."
}
```

Server must:

1. Create or update Aqua same-day repair ticket.
2. Create or update Service Appointment if FSL is used.
3. Route to assigned tech.
4. Add inventory requirement.
5. Return updated job DTO.

### Approve Closeout

```json
{
  "approvedBy": "005...",
  "notes": "QI passed. Photo package accepted."
}
```

Server must validate:

1. Required photos complete.
2. QI status is Passed.
3. No Red QI hold.
4. No open Finished Job required.
5. Invoice account is Builder Division.
6. Foreman is not the approver.

Then server must:

1. Set closeout approved fields.
2. Create Invoice__c or release invoice path.
3. Return updated job DTO.

## Empty states

Production API must return clean empty arrays and empty-state labels. Do not inject seed/demo rows when no real records exist.

## Error format

```json
{
  "ok": false,
  "code": "CLOSEOUT_QI_NOT_PASSED",
  "message": "Closeout is blocked until QI status is Passed.",
  "fieldErrors": []
}
```

Every production action error should also write `Error_Log__c` when the issue is system-side.

## 2026-05-14 Addendum: Takeoff, Site Readiness, Site Visits, QI, Aqua Check/Pickup, 2 PM Health Check

### Takeoff DTO

```ts
interface TakeoffLineItemDto {
  id: string;
  poLineItem: string;
  uom: string;
  poQuantity: number;
  verifiedQuantity: number | null;
  communityPackageQuantity: number;
  tolerance: number;
  status: "Not Verified" | "Match" | "Variance";
  notes?: string;
}
```

### Required endpoints or Apex methods

| Method | Purpose |
|---|---|
| `getFieldManagerWorkspace(userId)` | Returns current FM queue, selected job, takeoff rows, checklists, health checks, QI, Aqua records, photos, and actions. |
| `updateTakeoffVerifiedAmount(jobId, lineId, verifiedQuantity)` | Saves FM-measured amount for a PO-generated takeoff line. |
| `validateTakeoff(jobId)` | Compares PO amount, verified takeoff amount, and community package amount. Moves to Ready to Schedule only if all gates pass. |
| `completeChecklistItem(jobId, area, itemId)` | Toggles or completes takeoff, site readiness, Aqua check, or Aqua pickup checklist item. |
| `createSiteVisitDecision(jobId, purpose, decision, notes, photos)` | Saves FM site visit decision: Warranty, Finished Job, Proposal Needed, or No LOVING Action. |
| `submitHealthCheck(jobId, scopeRemainingPct, canFixTomorrow, status, notes)` | Saves 2 PM health check result and triggers FM alert if Red. |
| `submitQiInspection(jobId, scores, notes, photoIds)` | Saves QI 24-48 hours after Field Complete. Blocks closeout if score is below threshold. |
| `completeAquaCheck(ticketId, checklist, issueFlags, sodScore, photos)` | Completes recurring Aqua check or creates Same-Day Repair if needed. |
| `completeAquaPickup(ticketId, retrievedItems, varianceReason, photos)` | Completes pickup and reconciles inventory. Missing/damaged variance routes to billing or warranty. |

### Salesforce mapping notes

| Screen concept | Salesforce object / field target |
|---|---|
| PO line source | Builder_PO__c and related PO line object or parser output. If no line object exists, create a PO line DTO service from parsed PO data. |
| Verified takeoff quantity | Takeoff_Line__c.Verified_Quantity__c or Work_Order_Line_Item__c.Actual_Quantity__c only after architecture approval. Do not overload actual install quantity for pre-schedule takeoff without approval. |
| Community package amount | Community_Package__c or BMG pricing/package source. |
| 811 utility call | Takeoff_Task__c or Work_Order__c.Eight11_Task_Status__c temporary fallback. |
| Site readiness | Checklist__c / Checklist_Item__c, or Site Readiness Work Type if using FSL Work Plans. |
| Site visit | Site Visit Work Order / Service Appointment or custom Site_Visit__c if approved. |
| QI | QI_Inspection__c. |
| 2 PM health check | Foreman_Submission__c or Health_Check_Log__c depending on deployed org state. |
| Aqua check | Aqua_Check_Ticket__c. |
| Aqua pickup | Aqua_Pickup_Ticket__c. |
