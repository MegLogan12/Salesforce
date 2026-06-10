# Codex Build Spec: LOVING Field Manager Workspace

## 1. Context

You are building the LOVING Field Manager Workspace from the uploaded HTML visual source. The uploaded file is the visual contract. The new implementation must be interactive, data-driven, and iOS-capable while preserving the existing screen layout, color system, spacing, labels, and user flow.

The current package already contains a working React and Capacitor starter. Continue from this package. Do not rebuild from scratch unless the build is broken beyond repair.

## 2. Objective

Build one shared application that runs as:

| Target | Required Result |
|---|---|
| Desktop web page | Responsive React page that matches the uploaded Field Manager Execution Model. |
| iOS mobile app | Capacitor iOS app wrapping the same React app with mobile camera support for photo proof. |
| API-ready app | Data source can switch from local seed data to Salesforce Apex REST without changing the UI components. |
| Field Manager workflow | FM can select jobs, review proof, submit QI, return work, create Finished Jobs, dispatch Aqua repair, request reschedule, and approve closeout when gates pass. |

## 3. Non-negotiables

1. Do not change the visual design unless Meg explicitly approves it.
2. Do not change `src/styles/field-manager.css`.
3. Run `npm run verify:ui-lock` before every commit.
4. Do not hard-code job data in JSX.
5. UI text that represents operational data must come from `FieldManagerWorkspace` state or Salesforce DTOs.
6. Buttons cannot be toast-only for real actions.
7. Buttons must either create a record, update state, open a form, route work, validate a gate, upload proof, or show a clear disabled state.
8. Do not bill Builder Parent Accounts.
9. Do not allow closeout approval unless QI passed and gates are complete.
10. Do not allow QI submission without required photo categories.
11. Do not allow foreman closeout authority in this app.
12. Do not delete, rename, or deactivate Salesforce metadata without Meg approval.
13. No fake GPS pins, fake traffic, fake inventory, fake pricing, or fake invoice data in production mode.
14. In demo mode, seed data is allowed only through `src/data/seed-workspace.json`.
15. Mobile photo capture must use the device camera when available and desktop upload fallback when not available.

## 4. Audit first

Before coding, inspect these files:

| File | What to inspect |
|---|---|
| `original_locked_visual_source.html` | The visual source, content flow, CSS tokens, button labels, tab order, and desktop/mobile layout. |
| `src/styles/field-manager.css` | Locked visual CSS. Do not edit. |
| `src/data/seed-workspace.json` | The current DTO shape and seed records. |
| `src/types.ts` | Type definitions for workspace state. |
| `src/services/domainActions.ts` | Business actions and validation gates. |
| `src/services/salesforceApiClient.ts` | API replacement layer. |
| `docs/API_CONTRACT.md` | DTO and endpoint contract. |
| `docs/ACCEPTANCE_TESTS.md` | Required tests and acceptance criteria. |

Write an audit note before changing code:

| Area | Current State | Risk | Fix Needed | Approval Needed |
|---|---|---|---|---|

## 5. Source of truth

| Data Element | Demo Source | Production Source | Notes |
|---|---|---|---|
| Builder Parent | `JobRecord.breadcrumbs`, `ownership` | Account record type Builder Parent | Roll-up only. No transactions. |
| Builder Division | `JobRecord.breadcrumbs`, `invoicePreview` | Account record type Builder Market | Billing account. |
| Community | `JobRecord.breadcrumbs` | `Community__c` | Holds package and service rules. |
| Lot | `JobRecord.title`, `breadcrumbs`, `meta` | `Lot__c` | Physical install location. |
| WorkOrder | `JobRecord.workOrder` | `Work_Order__c` or standard `WorkOrder`, based on org decision | Primary execution record. |
| WorkOrder Line Items | `workOrder.lineItems` | `Work_Order_Line_Item__c` or `WorkOrderLineItem` | Scope and actuals. |
| Photos | `photos` | `Photo__c` plus ContentDocumentLink | Must be categorized. |
| QI | `qi` | `QI_Inspection__c` | 1-10 scoring. |
| Aqua | `aqua` | `Aqua_Install_Ticket__c`, `Aqua_Check_Ticket__c`, `Aqua_Pickup_Ticket__c` | Ticket-specific gates. |
| Invoice Preview | `invoicePreview` | `Invoice__c` | Must bill Division, not Parent. |
| Activity | `activity` | Chatter, `Work_Order_Note__c`, or audit object | Every action should leave a trail. |

## 6. Required architecture

### 6.1 Frontend

Use React with TypeScript.

Required structure:

```text
src/
  App.tsx
  main.tsx
  types.ts
  data/
    seed-workspace.json
  services/
    domainActions.ts
    fieldManagerRepository.ts
    salesforceApiClient.ts
  mobile/
    camera.ts
  styles/
    field-manager.css
```

Do not move visual styling into component libraries. Do not replace the CSS with Tailwind, Bootstrap, or a design system. The uploaded CSS is the visual source.

### 6.2 State model

The app must hold a `FieldManagerWorkspace` object with:

- current user
- selected job id
- work queue
- priorities
- job records
- form options

Each job must include:

- queue card data
- title, breadcrumbs, metadata
- stage labels and stage index
- KPI list
- next best actions
- ownership fields
- gate status
- takeoff fields and tasks
- work order fields and line items
- Aqua ticket state
- photo proof categories
- QI categories and score state
- invoice preview
- activity trail

### 6.3 Persistence

Demo mode:

- Load seed data from `seed-workspace.json`.
- Persist mutations to local storage.
- Provide reset to seed.
- Provide data export for debugging.

Production mode:

- Replace repository with `SalesforceFieldManagerApi`.
- Do not change UI components to switch data sources.
- No seed data in production responses.

### 6.4 iOS mobile app

Use Capacitor.

Required native support:

| Capability | Implementation |
|---|---|
| App wrapper | Capacitor iOS. |
| Camera photo proof | `@capacitor/camera`. |
| Safe area | `viewport-fit=cover`, Capacitor iOS content inset automatic. |
| Offline demo state | Local storage. |
| Future offline production state | IndexedDB or SQLite, only after approval. |

## 7. Required interactions

| User Action | Required Behavior | Must Update |
|---|---|---|
| Select job | Load selected job into all panels. | `selectedJobId`. |
| Advance stage | Move selected job to next stage. | `stageIndex`, activity. |
| Open Takeoff | Show selected job takeoff fields. | No mutation unless reviewed. |
| Review Schedule | Show selected job Service Appointment and crew data. | No mutation unless reschedule request sent. |
| Accept Photos | Validate photo category readiness. | Photo KPI, activity. |
| Add Photo | Capture or upload categorized proof. | `photos`, KPI, activity. |
| Submit QI | Validate photos and score categories. | `qi`, KPI, gates, stage, activity. |
| Create Finished Job | Create child FJ record path. | Activity, invoice blocked, stage. |
| Return Work | Send return note to selected owner. | QI status, queue pill, gate status, activity. |
| Request Reschedule | Submit request to Scheduling Manager. | Work order schedule request state, activity. |
| Dispatch Aqua Repair | Create or update Aqua repair ticket path. | Aqua KPI, health KPI, Aqua checks, activity. |
| Approve Closeout | Allowed only if QI passed and gates done. | Stage, invoice KPI, work order status, activity. |
| Export Data | Show current workspace JSON. | No mutation. |
| Reset Seed | Reset demo local state. | Entire workspace state. |

## 8. Salesforce production mapping

When wiring to Salesforce, build Apex REST endpoints or LWC/Apex controllers that return exactly the DTOs in `docs/API_CONTRACT.md`.

Do not let the frontend query raw Salesforce objects directly from many places. Use a single service layer so the UI stays stable.

Recommended Apex service classes:

| Apex Class | Purpose |
|---|---|
| `FieldManagerWorkspaceController` | Returns full workspace DTO for current FM. |
| `FieldManagerActionController` | Handles QI submit, closeout approval, return work, FJ creation, reschedule request, and Aqua dispatch. |
| `FieldManagerPhotoController` | Handles photo upload, category assignment, ContentDocumentLink, and photo metadata. |
| `FieldManagerGateService` | Central gate validation for photos, QI, closeout, Aqua, and invoice release. |
| `FieldManagerDtoFactory` | Converts Salesforce records into the frontend DTO. |

## 9. Approval gates

APPROVAL REQUIRED before any of these changes:

1. Editing the visual CSS.
2. Changing tab order or card layout.
3. Changing source of truth for Work Orders.
4. Changing billing account logic.
5. Changing QI score thresholds.
6. Changing required photo categories.
7. Changing FM permissions.
8. Changing Aqua ticket closeout gates.
9. Adding or deleting Salesforce fields.
10. Renaming API names or picklist values.
11. Adding production-only offline storage.
12. Publishing to TestFlight or App Store.

## 10. Build sequence

| Step | Owner | Task | Done When |
|---|---|---|---|
| 1 | Codex | Run audit first. | Audit note complete. |
| 2 | Codex | Install dependencies. | `npm install` succeeds. |
| 3 | Codex | Run UI lock. | `npm run verify:ui-lock` passes. |
| 4 | Codex | Run desktop app. | Vite page opens and no console errors. |
| 5 | Codex | Test job switching. | All tabs update when each queue job is selected. |
| 6 | Codex | Test state actions. | QI, return, FJ, repair, photo, closeout mutate state and activity. |
| 7 | Codex | Build production assets. | `npm run build` passes. |
| 8 | Codex | Init iOS. | `npm run ios:init` creates iOS project. |
| 9 | Codex | Sync iOS. | `npm run ios:sync` succeeds. |
| 10 | Codex | Open Xcode. | iOS app opens and runs in simulator. |
| 11 | Codex | Write final report. | Report includes tests, failures, open risks, and next actions. |

## 11. Required tests

Automated tests should cover:

1. Selecting each job changes selected job state.
2. Submitting QI before enough photos fails.
3. Submitting QI with enough photos calculates average score.
4. QI pass unlocks closeout readiness.
5. QI red holds closeout.
6. Closeout approval fails if QI not passed.
7. Closeout approval succeeds only after all gates pass.
8. Return work changes queue to NFI and blocks invoice.
9. Finished Job creation logs child WO path.
10. Aqua repair dispatch updates Aqua and health KPIs.
11. Photo upload adds a categorized proof record.
12. UI lock fails if frozen CSS changes.

Manual tests are listed in `docs/ACCEPTANCE_TESTS.md`.

## 12. Rollback

| Area | Rollback |
|---|---|
| Desktop build | Revert to prior Git commit and redeploy prior `dist/`. |
| Local demo data | Click Reset Seed Data or clear local storage key `loving-field-manager-workspace:v1`. |
| iOS app | Re-sync previous build in Capacitor, rebuild in Xcode, and redeploy. |
| Salesforce API wiring | Switch repository back to local API implementation while backend is corrected. |
| Production Salesforce action failure | Apex action must throw a user-safe error and write `Error_Log__c`. No partial closeout approval. |

## 13. Stop conditions

Stop and ask Meg before continuing if:

1. You need to edit the locked CSS.
2. A visual change appears necessary.
3. A Salesforce field or API name is missing or conflicts with spec.
4. A button cannot perform a real action.
5. Closeout would bill a Parent Account.
6. QI threshold or score logic is unclear.
7. Required photo categories are unclear.
8. iOS camera permission or signing requires Apple account access.
9. A production deployment would touch metadata outside this scope.

## 14. Final report format

When finished, return:

| Area | Status | Evidence | Open Issue | Recommendation |
|---|---|---|---|---|

Include:

- Commands run
- Tests passed
- Tests failed
- Build output path
- iOS status
- Files changed
- Approval items
- Next action

## 2026-05-14 Meg Revision: Operational Detail Addendum

This addendum is now part of the build contract. Do not treat the Field Manager page as a static mockup. Keep the uploaded HTML visual look, but the underlying logic must support real operating data and real state transitions.

### 1. Takeoff must be generated from PO line items

When a Builder PO is created or imported, the system must generate a Takeoff Checklist from the PO line items. The Field Manager does not manually create the checklist rows.

Required table structure:

| Column | Required behavior |
|---|---|
| PO Line Item | Pulled from Builder_PO__c line data or PO parser output. Examples: Sod, Street Tree, Shrubs, Mulch. |
| UOM | Unit of measure from the PO line. Examples: SQFT, EA, CY, LF. Use exact abbreviations. |
| PO Amount | Quantity from the purchase order. Example: Sod = 4600. |
| Verified Amount | Numeric text-enabled field where the FM enters measured field quantity. This must be editable on desktop and mobile. |
| Community Package | Expected quantity from the Community Package or BMG package configuration. |
| Status | System-calculated: Not Verified, Match, or Variance. |

Codex must not hardcode Lot 118 quantities into JSX. Seed data is allowed only in `src/data/seed-workspace.json` for demo mode. Production values must come from Salesforce DTOs.

### 2. Takeoff validation logic

The system must compare three numbers before moving to Ready to Schedule:

1. PO Amount
2. Verified Takeoff Amount entered by FM
3. Community Package Amount

When all required rows are verified and match within tolerance:

- Takeoff status becomes Validated.
- Work Order status becomes Ready to Schedule.
- Stage rail moves to Ready to Schedule.
- Gate status marks Takeoff complete.
- Activity feed records the validation.

When a variance exists:

- Takeoff status becomes Variance.
- Job cannot move to Ready to Schedule.
- Queue pill becomes Mismatch Review.
- Job must go to CSM review or COO review if over the approved variance threshold.

Required blocked conditions:

- Missing Verified Amount on any PO line item.
- Complete 811 Utility Call not done.
- Required takeoff checklist items not done.
- Required takeoff photos missing.
- Variance between PO, verified takeoff, and community package beyond tolerance.

### 3. Complete 811 Utility Call

The takeoff checklist must include `Complete 811 Utility Call`. It is not optional. The job cannot move to Ready to Schedule unless it is marked complete.

Salesforce field target:

| Concept | Preferred field / object |
|---|---|
| 811 task row | Takeoff_Task__c.Task_Type__c = 811 Utility Mark, or Work_Order__c.Eight11_Task_Status__c if Takeoff_Task__c is not deployed yet |
| 811 completion | Takeoff_Task__c.Status__c = Complete, Completed_Date__c populated |
| Temporary fallback | Work_Order__c.Eight11_Task_Status__c = Cleared |

### 4. Site readiness is separate from takeoff

Site readiness happens 48 hours before the job starts. It is not the same thing as takeoff. It must be a separate checklist.

Required site readiness checklist:

- Grading complete.
- Access and staging clear.
- Utilities marked and visible.
- Builder conflicts checked.
- Site not blocked by other trades.
- Weather or standing water reviewed.

If site readiness fails, the Work Order should move to Site Not Ready or hold, and Scheduling Manager must review.

### 5. Site visits

Site visits are decision records. They are used when LOVING needs to physically inspect a proposed issue or new work request and decide what it really is.

Supported site visit purposes:

| Purpose | Result options |
|---|---|
| Warranty Determination | Warranty, Finished Job, Proposal Needed, No LOVING Action |
| Finished Job Determination | Finished Job, Warranty, Proposal Needed, No LOVING Action |
| Proposal Scope | Proposal Needed, No Proposal, Builder Clarification Needed |

A site visit must collect photos, notes, scope measurements when applicable, and a final FM decision. Do not let the system silently convert every complaint into warranty work. That is how margins leak out the back door.

### 6. Quality Inspection timing and style

QI is performed 24 to 48 hours after the foreman finishes the job. It is not the same as foreman closeout.

The QI screen should use a landscape-themed rating experience while staying professional. The current implementation uses slider-style ratings with labels like Rooted and Ready, Garden Glow, Clean Sweep, Water Wizard, Curb Appeal, and Builder Smile.

QI must evaluate:

- Quality of work.
- Photo proof.
- Site cleanup.
- No unresolved complaints.
- Aqua quality when applicable.
- Whether a Finished Job is required.

QI score below threshold blocks closeout and requires Finished Job workflow.

### 7. Aqua check and Aqua pickup are checklist-driven

Aqua Check is a checklist. Aqua Pickup is a pickup and reconciliation checklist.

Aqua Check required checklist:

- Device present and functioning.
- Coverage check complete.
- Sod condition score entered.
- Photos uploaded.
- Same-day issue flag if dry spot, broken head, timer issue, runoff, device missing, or tamper issue exists.

Aqua Pickup required checklist:

- Device retrieved.
- Inventory reconciled.
- Variance reviewed.
- Pickup photos uploaded.
- Missing or damaged inventory routed to billing or warranty workflow based on reason code.

### 8. 2 PM crew health check

The FM workspace must show the 2 PM health check for crews and jobs. It is a daily operational checkpoint, not a decorative status.

Required fields:

| Field | Purpose |
|---|---|
| Due time | Usually 2:00 PM local time |
| Crew | Crew or Service Resource |
| Foreman | Crew lead submitting the status |
| Status | Green, Red, or Awaiting Response |
| Scope remaining % | How much of the job remains |
| Can fix tomorrow | Whether the issue can be solved without a Finished Job |
| Notes | What the FM needs to know |

Red health checks should prompt FM decision: Finished Job, crew extension, reschedule, or escalation.

### 9. Data source rule

All of these screens must be wired to DTOs and actions, not hardcoded HTML. For local demo mode, the only allowed seed values live in `src/data/seed-workspace.json`.

Required service functions now included:

- `updateTakeoffVerifiedAmount`
- `validateTakeoff`
- `completeChecklistItem`
- `submitQiPass`
- `dispatchAquaRepair`
- `approveCloseout`

Production wiring must replace local repository calls with Salesforce Apex REST or LWC Apex methods, using the same DTO shape.
