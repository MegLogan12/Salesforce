# LOVING Production Deployment Log

All entries are production deployments to `megan.logan@thelovingcompanies.com`.
Format: deploy date · components · tests · coverage · smoke · notes.

---

## 2026-05-20 — Dispatch Map

**Components deployed:**
| Component | Type |
|---|---|
| `DispatchMapController` | Apex Class |
| `DispatchMapControllerTest` | Apex Test Class |
| `lovingDispatchMap` | Lightning Web Component (4 files) |
| `Dispatch_Map` | FlexiPage (AppPage) |
| `Dispatch_Map` | Custom Tab |
| `Field_Service_Console` | Connected App (tab + workspace mapping added) |

**Tests:** 3/3 passing (`DispatchMapControllerTest`)
**Coverage:** `DispatchMapController` 97%
**Test approach:** Fully deterministic — no `@SeeAllData`. Isolated chain: `OperatingHours → ServiceTerritory → Account → ServiceAppointment → User → ServiceResource (T-type) → ServiceTerritoryMember → AssignedResource`.

**Smoke test (programmatic, loving-prod):**
- Controller executes live and returns 5 pins for today's demo appointments
- All pins have appointment number, unit name, driver name, city, street, lat/lng
- Charlotte geocoordinates confirmed on all 5 ServiceAppointments
- Tab present in Field_Service_Console after Scheduling_Console (tabs + workspace mappings)
- FlexiPage retrieved from production and confirmed referencing `lovingDispatchMap` LWC

**Remaining minor item:**
- `lovingOpsLinks` Ops Links LWC not wired into `LOVING_Field_Service_UtilityBar` via metadata deploy. Platform API has a hardcoded validation loop for custom LWCs in utility bars. Requires 2-minute step in Lightning App Builder UI. No impact on Dispatch Map or any other feature.

---
