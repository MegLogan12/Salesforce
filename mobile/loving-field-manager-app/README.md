# LOVING Field Manager Workspace

## TL;DR

This package converts the uploaded Field Manager Execution Model into a data-driven React desktop page and an iOS-ready Capacitor app while preserving the uploaded visual design. The CSS is locked from the uploaded HTML source. Do not change the visual CSS unless Meg explicitly approves a design change.

## What is included

| Area | File / Folder | Purpose |
|---|---|---|
| Frozen visual source | `original_locked_visual_source.html` | The uploaded visual contract. Keep for comparison. |
| Locked CSS | `src/styles/field-manager.css` | Extracted from the uploaded HTML. Guarded by a SHA check. |
| Desktop app | `src/App.tsx` | React implementation of the Field Manager workspace. |
| Data source | `src/data/seed-workspace.json` | Seed data for the demo. Components read from this state, not fixed Lot 118 text. |
| Domain actions | `src/services/domainActions.ts` | Real state transitions for QI, return, photos, FJ, Aqua repair, reschedule, and closeout. |
| Persistence | `src/services/fieldManagerRepository.ts` | Local storage repository for desktop and iOS demo mode. |
| API-ready layer | `src/services/salesforceApiClient.ts` | Interface for replacing local storage with Salesforce REST or Apex REST. |
| iOS wrapper | `capacitor.config.ts` | Capacitor configuration for iOS packaging. |
| Codex spec | `docs/CODEX_BUILD_SPEC.md` | The full instruction set for Codex. |
| API contract | `docs/API_CONTRACT.md` | DTOs and endpoints required to replace demo data with Salesforce records. |
| Tests | `docs/ACCEPTANCE_TESTS.md` and `src/services/domainActions.test.ts` | Behavioral test scenarios and starter automated tests. |

## Run locally

```bash
npm install
npm run verify:ui-lock
npm run dev
```

Open the Vite URL in a browser.

## Build desktop web

```bash
npm run verify:ui-lock
npm run build
npm run preview
```

The production web assets are emitted to `dist/`.

## Build iOS app

```bash
npm install
npm run verify:ui-lock
npm run build
npm run ios:init
npm run ios:sync
npm run ios:open
```

In Xcode:

1. Select the signing team.
2. Confirm bundle id: `com.loving.fieldmanager`.
3. Confirm app name: `LOVING Field Manager`.
4. Run on iPhone simulator first.
5. Run on a real iPhone after signing is set.

## Non-negotiables

1. Preserve the uploaded visual design.
2. Do not edit `src/styles/field-manager.css` without explicit approval.
3. Keep all operational data outside the React markup.
4. Every action must create, update, route, validate, upload, or persist something real.
5. No Parent Account billing.
6. FM can approve closeout, return work, submit QI, create Finished Job, and dispatch Aqua repair.
7. Foreman cannot close Work Orders.
8. Invoice path unlocks only after closeout/QI gates pass.
9. Mobile is the FM review and approval flow, not the foreman-only execution flow.
10. Do not delete objects, fields, picklist values, or API names without Meg approval.

## Meg revision included: interactive operating detail

This package now includes the requested operational detail:

- PO-generated takeoff line item checklist.
- Editable Verified Amount field next to each PO Amount.
- System match between PO Amount, Verified Takeoff Amount, and Community Package Amount.
- Complete 811 Utility Call gate.
- Separate 48-hour Site Readiness checklist.
- Site Visit decision records for Warranty, Finished Job, or Proposal Scope.
- Landscape-themed QI rating sliders for the 24-48 hour post-field-complete inspection.
- Aqua Check checklist.
- Aqua Pickup checklist.
- 2 PM crew health check panel.

The visual CSS remains locked to the uploaded HTML source. Use `npm run verify:ui-lock` to confirm no visual drift.
