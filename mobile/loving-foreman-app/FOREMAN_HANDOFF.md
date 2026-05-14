# LOVING Foreman Handoff

Use this app folder, not the old combined app:

- `mobile/loving-foreman-app`

Design reference:

- `reference/02_FSL_Mobile_Foreman.html`

What this app is supposed to be:

- standalone LOVING Foreman app
- same UI/visual/colors/card language as the approved HTML
- active work should come from the selected `ServiceAppointment` and its `ParentRecordId` standard `WorkOrder`
- no lunch workflow
- no 2 PM Health Check

Current important notes:

- this split app was separated from the older combined `loving-field-app`
- the main UI file is `src/core/App.tsx`
- local runtime auth depends on Expo public env values
- `.env` is intentionally excluded from the zip

Run locally:

```bash
cd mobile/loving-foreman-app
npm install
npm run typecheck
npm run start
```

Web check:

```bash
cd mobile/loving-foreman-app
npm run web
```

iOS export check:

```bash
cd mobile/loving-foreman-app
npx expo export --platform ios
```

What to inspect first:

1. `src/core/App.tsx`
2. `src/salesforce/SalesforceService.ts`
3. `src/salesforce/session.ts`
4. `src/data/contracts.ts`
5. `reference/02_FSL_Mobile_Foreman.html`

Known area to verify:

- local OAuth/env wiring for the split app
- final visual parity of every Foreman screen against the HTML
- active-work flow from `ServiceAppointment -> ParentRecordId -> WorkOrder`
