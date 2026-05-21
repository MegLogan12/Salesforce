# LOVING Field Manager App Handoff

This package contains the React Native / Expo app source that currently hosts the Field Manager mock experience.

## Primary entry point

- `src/app/App.tsx`

## Field Manager mock files

- `src/screens/FieldManagerMockScreen.tsx`
- `src/data/fieldManagerMock.ts`

## Shared files the mock depends on

- `src/app/types.ts`
- `src/data/contracts.ts`
- `src/design/tokens.ts`
- `src/design/theme.ts`
- `src/components/FieldButton.tsx`

## Current behavior

- The app contains both the Foreman flow and the Field Manager mock.
- From the sign-in screen, choose `Open Field Manager Mock`.
- The Field Manager mock includes:
  - My Day cards
  - appointment types for:
    - Take-Offs
    - Quality Inspection
    - Site Readiness
    - Customer Care
    - Aqua Check-Work Order
    - Aqua Pick-Up-Work Order
  - 2 PM Health Check
  - Foreman / Crew drill-in
  - mock appointment detail actions

## Run locally

```bash
npm install
npm run start
```

## Notes

- This package excludes `.env`, `.git`, `node_modules`, and build artifacts.
- The Field Manager portion is currently a mock UI/data layer, not yet wired to live Salesforce records.
