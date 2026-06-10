# Production UI Cleanup Audit
**Date:** 2026-06-04  
**Scope:** All visible Salesforce UI — flows, LWCs, tabs, app navigation, flexipages  
**Goal:** Remove all instructional build-language, onboarding cards, explanatory placeholders, and training-style wording from production-facing workflows.

---

## Summary

| Category | Items Found | Items Changed | Items Kept |
|---|---|---|---|
| LWC notice banners | 14 | 14 (condensed) | 0 |
| Flow screen copy | 5 | 5 | 0 |
| Tab labels | 2 | 2 (renamed) | 0 |
| App navigation | 1 | 3 (home, removal, lock) | 0 |
| Flexipage labels | 1 | 0 (content is real) | 1 |

---

## Changes Made

### 1. LWC — `lovingWorkOrderTypeLayout` NOTICE_MAP
**File:** `force-app/main/default/lwc/lovingWorkOrderTypeLayout/lovingWorkOrderTypeLayout.js`  
**Lines:** 20–35  
All 14 NOTICE_MAP entries rewritten from multi-sentence explanatory paragraphs to concise operational labels. See `PRODUCTION_UI_REMOVE_HIDE_REWRITE_MATRIX.csv` for before/after.

### 2. Flow — `LOVING_2PM_Health_Check_Response`
**File:** `force-app/main/default/flows/LOVING_2PM_Health_Check_Response.flow-meta.xml`  
**Line:** 389  
Removed motivational explanation; kept the directive statement.

### 3. Flow — `LOVING_Foreman_EOD_Summary`
**File:** `force-app/main/default/flows/LOVING_Foreman_EOD_Summary.flow-meta.xml`  
**Line:** 99  
Removed "Good work today!" encouragement opener; kept bilingual instruction.

### 4. Flow — `LOVING_Delivery_QC_FM_Decision`
**File:** `force-app/main/default/flows/LOVING_Delivery_QC_FM_Decision.flow-meta.xml`  
**Line:** 271  
Replaced 2-sentence process explanation with a single directive.

### 5. Flow — `ODL_Create_Lennar_Vouchers`
**File:** `force-app/main/default/flows/ODL_Create_Lennar_Vouchers.flow-meta.xml`  
**Line:** 150  
Removed instructional text about voucher format (belongs in flow description, not the UI screen).

### 6. Flow — `Create_Builder_Account_Cascade`
**File:** `force-app/main/default/flows/Create_Builder_Account_Cascade.flow-meta.xml`  
**Lines:** 702, 787  
Line 702: Removed "Parent Account will be auto-populated…" — behavior is implicit.  
Line 787: Condensed navigation instruction from 18 words to 9.

### 7. Tab — `LOVING_Foreman_Mobile_App`
**File:** `force-app/main/default/tabs/LOVING_Foreman_Mobile_App.tab-meta.xml`  
Label changed from "Foreman Prototype" → "Foreman".

### 8. App — `Field_Service_Console`
**File:** `force-app/main/default/applications/Field_Service_Console.app-meta.xml`  
- Removed `standard-home` tab (placeholder home)  
- Promoted `Scheduling_Console` to first tab (new landing page)  
- Removed `Customer_Success_Console` from tabs and workspaceConfig  
- Set `isNavPersonalizationDisabled = true` (eliminates "More" dropdown)

---

## Items Reviewed and Kept

### `Getting_Started_Home` flexipage
Despite the label, this page contains real production content: Sales Person Activity report chart, Team Pipeline, Leads by Source, opportunity filter lists, today's tasks and events. Label is misleading but content is valid — not changed.

---

## Items Not in Scope (Out of Reach)

| Item | Reason |
|---|---|
| Help text on field definitions | Requires Schema Builder or Setup UI — not in metadata files |
| Dynamic form section headers set via record type | Controlled by page layouts, not audited |
| Einstein/Guidance panels | Platform feature, not custom metadata |
