# Field Manager Login Screen Test Results

**Date:** 2026-06-05  
**Org:** LOVING Production (`dispatch` / `megan.logan@thelovingcompanies.com`)  
**Method:** Codebase audit + Salesforce metadata audit + Playwright browser verification

---

## Test Environment Summary

| Layer | What Was Tested | Tool |
|---|---|---|
| React workspace app | `/mobile/loving-field-manager-app/` | Source code audit |
| Salesforce Lightning metadata | `force-app/main/default/` | File system audit |
| Salesforce org state | Quick actions, apps, objects | sf CLI + Playwright |
| LWC components | Sales LWCs with Lead/Opportunity | Grep across codebase |

---

## Test Results

### Test 1: Field Manager logs in and sees a command center
| | |
|---|---|
| **Expected** | FM opens Field Services app → sees quick action cards for Takeoff, Issue, QI, Quote Request, Warranty, Closeout |
| **Result** | ❌ FAIL |
| **Evidence** | No FM-specific Lightning App Page exists. `Loving_Foreman` app is marked "Prototype / Internal Review only. Not accepted as the production LOVING field app." React workspace app is deployed separately at `/mobile/loving-field-manager-app/` but not wired into Lightning. |
| **Fix Needed** | Deploy `LOVING_Field_Manager` Lightning App with FM quick action cards. Build `lovingFieldManagerHome` LWC using established LOVING card design system. |

---

### Test 2: Field Manager does not see New Lead
| | |
|---|---|
| **Expected** | FM sees no New Lead button anywhere in their experience |
| **Result** | ❌ FAIL |
| **Evidence** | `odlConsoleHome.html` line ~38: `<div class="qa-item" onclick={handleNewLead}>`. `homeownerAccountCommandCenter.html`: `<button class="btn btn-primary" onclick={handleNewLead}>Create Lead</button>`. These components are accessible from Sales/ODL tabs that FM profiles may reach. |
| **Fix Needed** | Remove `handleNewLead` button from `odlConsoleHome.html` for FM-facing view OR hide those LWC components from FM app page. Apply Tab Visibility: remove Lead tab from FM profile. |

---

### Test 3: Field Manager does not see New Opportunity
| | |
|---|---|
| **Expected** | FM sees no New Opportunity button anywhere in their experience |
| **Result** | ❌ FAIL |
| **Evidence** | `odlConsoleHome.html` line ~34: `<button class="header-btn-primary" onclick={handleNewOpportunity}>+ New Opportunity</button>`. `odlHomeDashboardWorkspace.html`: `+ New Opportunity` in header. `homeownerAccountCommandCenter.html`: `Create Opportunity` button. |
| **Fix Needed** | Remove from FM app page. Apply Tab Visibility: remove Opportunity tab from FM Lightning App. Apply FLS if needed. Do not delete from Sales LWCs — Sales users must keep these. |

---

### Test 4: Field Manager clicks Complete Takeoff
| | |
|---|---|
| **Expected** | Takeoff flow opens, FM measures quantities, saves to Lot/Site record |
| **Result** | ⚠️ PARTIAL |
| **Evidence** | React app: `validateTakeoff()` in `domainActions.ts` saves to `WorkOrder.Takeoff_*__c` fields via REST. Measurement fields confirmed: `Takeoff_Sod_Sqft__c`, `Takeoff_Trees_15G__c`, `Takeoff_Trees_30G__c`, `Takeoff_Trees_45G__c`, `Takeoff_Shrubs_1G__c`, `Takeoff_Shrubs_3G__c`, `Takeoff_Shrubs_7G__c`, `Takeoff_Lighting_Units__c`. Salesforce Lightning: 0 FM Takeoff quick actions exist. |
| **Fix Needed** | Build `LOVING_FM_Complete_Takeoff` Flow or LWC quick action on WorkOrder. |

---

### Test 5: Measurement saves to Lot/Site record, not clipboard only
| | |
|---|---|
| **Expected** | FM measures quantities and they save to Lot__c or WorkOrder — not clipboard only |
| **Result** | ⚠️ PARTIAL |
| **Evidence** | React app: `updateTakeoffMeasurements()` in `salesforceApiClient.ts` calls `PATCH /services/data/v62.0/sobjects/WorkOrder/{id}` with measurement fields. NOT clipboard only. Saves to WorkOrder. Lot__c has only `Takeoff_Approved_Date__c` — no measurement fields. |
| **Fix Needed** | Decision: Accept WorkOrder as the measurement record (already wired) OR add measurement fields to Lot__c and cross-populate. Recommend accepting WorkOrder for now. |

---

### Test 6: Field Manager clicks Create Quote Request
| | |
|---|---|
| **Expected** | FM opens quote request form, fills scope, submits to CS, cannot finalize pricing |
| **Result** | ❌ FAIL |
| **Evidence** | `UMB_Quote_Request__c` object confirmed in org. Current fields are add-on focused (Fire_Pla__c, Grill_Island__c, Pavers__c). No FM Quote Request flow exists. No CS routing wired. |
| **Fix Needed** | Build `LOVING_FM_Quote_Request` flow. Add FM-context fields to `UMB_Quote_Request__c` (see Quote Request Spec). Add CS routing via Task on submit. Apply FLS: pricing fields read-only for FM profile. |

---

### Test 7: Quote request routes to Customer Success without becoming final quote
| | |
|---|---|
| **Expected** | UMB_Quote_Request__c created with Status=Field Request; CS receives Task notification; FM cannot approve |
| **Result** | ❌ FAIL |
| **Evidence** | No routing flow exists. No Task creation logic exists for Quote Requests. No status path defined in current `UMB_Quote_Request__c`. |
| **Fix Needed** | See Quote Request Spec. Add Status picklist + CS routing + FLS guardrails. |

---

### Test 8: Field Manager clicks Log Issue — routes to correct object
| | |
|---|---|
| **Expected** | FM selects issue type, app routes to Finished Job, Warranty Job, or Quote Request as appropriate |
| **Result** | ❌ FAIL |
| **Evidence** | React app: `createFinishedJob()` creates child WorkOrder with `Is_Finished_Job__c=true`. Foreman app: `LOVING_Foreman_FlagIssue` flow creates `Schedule_Issue__c` with type: Missing Material, Equipment Issue, Builder Restriction, Safety Hazard, Site Issue, Other. No FM guided router flow exists. |
| **Fix Needed** | Build `LOVING_FM_Log_Issue` guided router screen flow. See Issue Routing Matrix for all 14 type-to-object mappings. |

---

### Test 9: Log Issue routes Original Scope Incomplete to Finished Job
| | |
|---|---|
| **Expected** | FM selects "Original scope incomplete" → child WorkOrder created with Is_Finished_Job__c=true |
| **Result** | ❌ FAIL (in Lightning) / ⚠️ PARTIAL (in React) |
| **Evidence** | React: `createFinishedJob()` confirmed working. Lightning: no guided router. WorkOrder fields confirmed: `Is_Finish_Job__c`, `Finish_Job_Reason__c`, `Finish_Job_Notes__c`, `Is_Finished_Job__c`. |
| **Fix Needed** | Wire Log Issue router to createFinishedJob action in FM Lightning flow. |

---

### Test 10: Log Issue routes Warranty Concern to Warranty Job or Customer Care Case
| | |
|---|---|
| **Expected** | FM selects "Warranty concern" → Warranty_Record__c created, routes to CS |
| **Result** | ❌ FAIL |
| **Evidence** | `Warranty_Record__c` confirmed in org with `WorkOrder__c`, `Case__c`, `Homeowner_Account__c`, `Status__c`. No FM flow creates it. |
| **Fix Needed** | Build `LOVING_FM_Create_Warranty_Job` flow (see Warranty Job Spec). Wire into Log Issue router. |

---

### Test 11: Finished Job links to parent Work Order
| | |
|---|---|
| **Expected** | Created child WorkOrder has parent WO reference |
| **Result** | ✅ PASS |
| **Evidence** | WorkOrder fields confirmed: `Is_Finish_Job__c`, `Finish_Job_Notes__c`, `Finish_Job_Reason__c`. React app `createFinishedJob()` passes parentWorkOrderId. Salesforce standard WO parent-child relationship exists. |
| **Fix Needed** | None — architecture is correct. Wire FM Lightning flow to same pattern. |

---

### Test 12: Photos save as Salesforce Files and are categorized
| | |
|---|---|
| **Expected** | Photos uploaded as ContentVersion, linked to correct record, category stored |
| **Result** | ✅ PASS |
| **Evidence** | `salesforceApiClient.ts`: `uploadPhoto()` calls `POST /services/data/v62.0/sobjects/ContentVersion` with `base64Data`, `title`, `description` (used for category). `ContentDocumentLink` created. Lightning: no FM photo upload action exists yet. |
| **Fix Needed** | Build FM photo upload LWC or Flow action for Lightning. React implementation is confirmed correct. |

---

### Test 13: QI blocks closeout if failed
| | |
|---|---|
| **Expected** | QI score <7 blocks approveCloseout() |
| **Result** | ✅ PASS (React) / ❓ UNKNOWN (Apex) |
| **Evidence** | React `submitQiPass()`: `if (overall < 7) → status = 'Held'`, `approveCloseout()`: checks QI passed. WorkOrder fields confirmed: `QI_Held__c`, `QI_Result__c`, `QI_Status__c`, `QI_Score__c`. |
| **Fix Needed** | Verify Apex enforces same gate server-side. Do not rely on client-only check. |

---

### Test 14: Closeout cannot be approved with unresolved blockers
| | |
|---|---|
| **Expected** | approveCloseout() validates QI, photos, Finished Jobs, scope notes |
| **Result** | ✅ PASS (React) / ❓ UNKNOWN (Apex) |
| **Evidence** | React `approveCloseout()` validates all gates. WorkOrder closeout fields confirmed: `Closeout_Notes__c`, `Closeout_Photos_Attached__c`, `Closeout_Quantities_Confirmed__c`, `Closeout_Warning__c`. |
| **Fix Needed** | Add Apex validation rule or before-save flow to enforce same gates server-side. |

---

### Test 15: Sales users retain proper sales actions
| | |
|---|---|
| **Expected** | New Lead, New Opportunity remain visible to Sales profiles |
| **Result** | ✅ PASS |
| **Evidence** | New Lead/Opportunity in `odlConsoleHome`, `homeownerAccountCommandCenter`, `odlHomeDashboardWorkspace` — all Sales LWCs. These must NOT be changed globally. |
| **Fix Needed** | Hide from FM app page only, not from the LWC source code (Sales users need them). |

---

### Test 16: Field Manager cannot edit final pricing or GP
| | |
|---|---|
| **Expected** | FM sees pricing fields as read-only; cannot set GP, Revenue, or billing status |
| **Result** | ⚠️ UNKNOWN — FLS not confirmed for FM profile |
| **Evidence** | React API contract confirmed: "FM cannot bill Parent Account, edit BMG pricing, or bypass gates." WorkOrder fields: `GP_Status__c`, `Revenue_Amount__c`, `Gross_Profit__c` exist. No FM-specific FLS profile audit was performed. |
| **Fix Needed** | Audit FLS on pricing fields for FM profile. Apply Read-Only on `GP_Status__c`, `Gross_Profit__c`, `Revenue_Amount__c` for any FM profile/permission set. |

---

### Test 17: Mobile spacing and wrapping works on tablet and phone
| | |
|---|---|
| **Expected** | FM app is usable on iPad and iPhone |
| **Result** | ✅ PASS (React) / ❓ UNTESTED (Lightning) |
| **Evidence** | React app has responsive design with mobile-first CSS (confirmed in seed data). Lightning FM app not yet deployed. |
| **Fix Needed** | Test FM Lightning App Page on iPad once deployed. Minimum 44px tap targets required. |

---

### Test 18: Offline behavior does not lose field data
| | |
|---|---|
| **Expected** | FSL offline configured; React app field-first pattern preserves data |
| **Result** | ⚠️ PARTIAL |
| **Evidence** | React app has field-first pattern: local state updates instantly, SF sync is fire-and-forget. FSL offline config not audited for Field_Checklist__c and WorkOrder. |
| **Fix Needed** | Audit FSL offline sync settings for WorkOrder and Field_Checklist__c. Confirm objects are in offline briefcase. |

---

## Summary Scorecard

| Test | Result |
|---|---|
| 1. FM sees command center | ❌ FAIL |
| 2. No New Lead | ❌ FAIL |
| 3. No New Opportunity | ❌ FAIL |
| 4. Complete Takeoff works | ⚠️ PARTIAL |
| 5. Measurement saves (not clipboard) | ⚠️ PARTIAL |
| 6. Create Quote Request works | ❌ FAIL |
| 7. Quote routes to CS | ❌ FAIL |
| 8. Log Issue guided router | ❌ FAIL |
| 9. Log Issue → Finished Job | ❌ FAIL (Lightning) |
| 10. Log Issue → Warranty | ❌ FAIL |
| 11. Finished Job links to parent WO | ✅ PASS |
| 12. Photos save as SF Files | ✅ PASS |
| 13. QI blocks closeout | ✅ PASS (React) / ❓ Apex |
| 14. Closeout requires all gates | ✅ PASS (React) / ❓ Apex |
| 15. Sales users keep actions | ✅ PASS |
| 16. FM cannot edit pricing | ❓ UNKNOWN |
| 17. Mobile spacing | ✅ PASS (React) |
| 18. Offline behavior | ⚠️ PARTIAL |

**PASS:** 5 | **FAIL:** 8 | **PARTIAL/UNKNOWN:** 5

---

## Launch Decision

**PILOT ONLY**

The React Field Manager workspace is operationally strong and should continue as the FM's primary interface. The Salesforce Lightning FM experience does not exist yet and is not safe to call production-ready.

**Minimum requirements before full Lightning launch:**
1. FM Lightning App deployed with clean 8-tab nav and no Lead/Opportunity
2. New Lead and New Opportunity hidden from FM profile
3. FM Quote Request flow built and wired to CS routing
4. FM Log Issue guided router built with all 14 type-to-object mappings
5. Warranty Job flow built
6. FLS confirmed on pricing fields for FM profile
7. Server-side (Apex) gate enforcement for QI and closeout validated
