# UI Verification Log

Live screenshots captured from `loving-prod` via headless Chromium logged in as megan.logan@thelovingcompanies.com.

| Screenshot | URL | Verdict | Notes |
|---|---|---|---|
| `scheduling-console-before.png` | `/lightning/n/Scheduling_Console` | PASS render / FAIL data | LWC renders all sections correctly. Shows zeros because no Service Appointments today; Weather source not configured; WEX shows "stale" in integration health card. |
| `fs-console-home-before.png` | `/lightning/page/home?app=c__Field_Service_Console` | FAIL | Completely blank. Root cause: global HomePage.flexipage has no components. Fix on branch (commit 8e738d8). |
| `work-order-page-before.png` | `/lightning/r/WorkOrder/0WOVu000006sntBOAQ/view` | FAIL × 3 | Confirmed issues: section title says "Work Order Header" (fix on branch), small colored chips next to titles instead of full-row colored band (fix on branch), Foreman Mobile Actions are all wired to stub createTask() (NOT fixed this session). |
| `dispatch-map-current.png` | `/lightning/n/Dispatch_Map` | FAIL | "Page doesn't exist." Tab + FlexiPage exist in metadata but unreachable for admin user. Needs Setup investigation. |
| `dispatch-map-2.png` | `/lightning/app/standard__FieldServiceConsole/n/Dispatch_Map` | FAIL | App invalid. Wrong app prefix. |
| `dispatch-map-3.png` | `/lightning/app/c__Field_Service_Console/n/Dispatch_Map` | FAIL | Page doesn't exist. Tab may be hidden by profile. |
| `fs-app-default.png` | `/lightning/app/Field_Service_Console` | PASS (redirect) | Resolves to /lightning/page/home (still blank — same root cause). |

## Helper script

`verify-ui.js` at repo root. Usage:
```
node verify-ui.js "/lightning/page/home" "shot-name"
```
Uses the active sf CLI session token; logs into Lightning via frontdoor.jsp.
