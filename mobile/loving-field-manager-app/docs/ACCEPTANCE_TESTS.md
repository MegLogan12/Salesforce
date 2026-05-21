# Acceptance Tests: LOVING Field Manager Workspace

## TL;DR

The app is acceptable only if it preserves the uploaded visual design, loads all operational content from data/state, supports real state transitions, runs on desktop, and can be wrapped as an iOS app through Capacitor.

## Visual acceptance

| Test | Steps | Expected Result |
|---|---|---|
| UI lock | Run `npm run verify:ui-lock`. | Passes. CSS hash matches frozen source. |
| Desktop layout | Open at 1440px width. | Topbar, sidebar, record header, KPI grid, tabs, cards match source. |
| Tablet layout | Open at 820px width. | Layout collapses using existing media rules. No design rewrite. |
| Phone layout | Open at 390px width. | Mobile responsive layout works and Field Mobile View phone mock remains usable. |
| Tab order | Inspect tab bar. | Order remains: FM Command Center, Takeoff, WorkOrder, Aqua, Photos, QI, Field Mobile. |

## Data-driven acceptance

| Test | Steps | Expected Result |
|---|---|---|
| Job selection | Click Lot 204, Lot 77, Lot 44. | Header, KPIs, tabs, gates, photos, Aqua, and QI content change to selected job. |
| No fixed Lot 118 dependency | Select Lot 77 and open QI/Aqua/Photos. | Modal and tabs show Lot 77 values, not Lot 118 values. |
| Export state | Click Export Current Data. | JSON reflects current state and selected job. |
| Reset seed | Click Reset Seed Data. | Workspace returns to original seed data. |

## Interaction acceptance

| Test | Steps | Expected Result |
|---|---|---|
| Photo accept pass | Select Lot 118, Photos tab, Accept Photo Package. | Photo KPI/activity update and toast confirms acceptance. |
| Photo accept fail | Select Lot 204, Photos tab, Accept Photo Package. | Action fails because photo categories are incomplete. |
| Add photo | Select Lot 204, Photos tab, Add Photo card, save proof. | New categorized proof appears and local state persists. |
| Submit QI pass | Select Lot 118, Start QI Review, Submit QI Pass. | QI score calculates, QI status Passed, closeout Ready, invoice Ready. |
| Submit QI blocked | Select Lot 204, try QI. | QI fails because job is not ready and no QI categories are loaded. |
| Return work | Open Return Work modal and submit. | Queue pill becomes NFI, invoice blocks, activity logs return note. |
| Create Finished Job | Open Create Finished Job and submit scope. | Child FJ path logged and invoice remains blocked. |
| Aqua repair | Select Lot 77, Aqua repair modal, Dispatch Repair. | Aqua KPI and health KPI update, check row records repair. |
| Reschedule request | Open Request Reschedule and submit. | Activity logs request. Schedule Manager remains owner of actual change. |
| Closeout blocked | Try closeout before QI passed. | Error toast. No invoice created. |
| Closeout approved | Pass QI and approve closeout. | Stage moves to Invoice, invoice KPI Created, activity logs Division billing path. |

## iOS acceptance

| Test | Steps | Expected Result |
|---|---|---|
| iOS init | Run `npm run ios:init`. | iOS project is created. |
| iOS sync | Run `npm run ios:sync`. | Web assets sync to iOS. |
| Simulator run | Open in Xcode and run on iPhone simulator. | App loads and layout is usable. |
| Camera path | Open Add Photo and tap Use Mobile Camera on device. | Camera opens if permission granted. Saved proof appears in Photos. |
| Camera fallback | Run in desktop browser and use camera action. | App handles unavailable camera without crashing. |

## Production readiness acceptance

| Test | Required Evidence |
|---|---|
| API DTO match | Salesforce endpoint response matches `src/types.ts`. |
| No seed data in production | API returns real records or empty states only. |
| Closeout gate | Server rejects closeout if QI not passed. |
| Division billing | Server rejects invoice path if billing account is Builder Parent. |
| Activity trail | Every mutation creates a Salesforce audit event, task, note, or Chatter post. |
| Photo category gate | Server validates categories, not just raw file count. |
| Error logging | System-side action failure writes `Error_Log__c`. |

## 2026-05-14 Additional Acceptance Tests

| Test ID | Scenario | Expected Result |
|---|---|---|
| TK-01 | Open Takeoff tab | PO-generated line table displays PO Line Item, UOM, PO Amount, Verified Amount, Community Package, Status. |
| TK-02 | Enter verified amount for Sod | The row updates immediately and recalculates Match or Variance. |
| TK-03 | Leave one verified amount blank and click Validate | System blocks Ready to Schedule. |
| TK-04 | Mark Complete 811 Utility Call incomplete and click Validate | System blocks Ready to Schedule. |
| TK-05 | Enter verified amounts matching PO and community package and click Validate | Takeoff becomes Validated, Work Order becomes Ready to Schedule, activity log records validation. |
| TK-06 | Enter variance beyond tolerance | Takeoff becomes Variance and job stays out of scheduling. |
| SR-01 | Open Site Readiness | Checklist shows 48-hour pre-start readiness items. |
| SV-01 | Open Site Visit | Site visit decision rows show Warranty Determination, Finished Job Determination, or Proposal Scope. |
| HC-01 | Open WorkOrder tab | 2 PM health check panel shows due time, crew, foreman, status, remaining %, can fix tomorrow, and notes. |
| QI-01 | Open QI tab | QI shows landscape-themed slider ratings and 24-48 hour timing note. |
| AQ-01 | Open Aqua tab | Aqua Check checklist and Aqua Pickup checklist both display and update interactively. |
| UI-01 | Run `npm run verify:ui-lock` | CSS visual contract passes. |
| BUILD-01 | Run `npm run build` | TypeScript and Vite build pass. |
| TEST-01 | Run `npm test` | Domain action tests pass. |
