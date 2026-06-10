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

## 2026-05-20 — FSL Charlotte-North Run-Ready Configuration

**Type:** Production data/config changes (anonymous Apex — no metadata deploy)
**Org:** `megan.logan@thelovingcompanies.com`

**Changes made:**

| # | Change | Detail |
|---|---|---|
| 1 | Added 4 drivers to Charlotte-North | Scott Spaulding, Jamie Hinson, Jersain Laris, Victor Zambrano → Primary STM, EffectiveStartDate 2026-05-20 |
| 2 | Deactivated UAT resource | `UAT - Scheduling Console Test Resource` → IsActive=false |
| 3 | Added 22 core skills to 3 thin-skill drivers | Gustavo Perez (2→23), Juan Munoz (2→24), Justin Smithwick (1→23) — Jesus Alvelo 22-skill production baseline |

**Pre-change state:**
- Charlotte-North had 16 T-type drivers + 7 C-type units (23 total)
- 4 active T-type drivers had no territory membership (not schedulable)
- 1 UAT test resource was active (visible in Dispatcher Console)
- 3 drivers had 1–2 skills (below optimization threshold)

**Post-change state:**
- Charlotte-North: **21 T-type drivers + 7 C-type units = 28 active schedulable resources**
- UAT resource: inactive, no longer visible in console
- Gustavo/Juan/Justin: 23–24 skills each, matching production baseline

**Smoke test (programmatic, loving-prod):**
- Charlotte-North active member count: 28 (21 T + 7 C) ✓
- UAT - Scheduling Console Test Resource: IsActive=false ✓
- Named driver check — all 6 confirmed present and active: Nick Melendez, Trenton Kinard, Jamie Hinson, Jersain Laris, Scott Spaulding, Victor Zambrano ✓
- All Units 01–07 confirmed active in Charlotte-North ✓
- Gustavo Perez: 23 skills, Juan Munoz: 24 skills, Justin Smithwick: 23 skills ✓

---
