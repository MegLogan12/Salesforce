# CS Console Audit — production findings (Jun 10, 2026)

Audit-first per the CS Console build prompt §4. All findings verified against the
LOVING production org via describe calls, tooling-API validation rule reads, and
record counts. No org data or metadata was changed during the audit.

| Area | Item | Current state in production | Spec requirement | Gap / resolution | Approval needed |
|---|---|---|---|---|---|
| Objects | Builder_PO__c | Real, 70+ fields incl. Status__c (6 CS stages present), CS_Approved__c, NFI_Count__c, NFI_Reason__c, Mismatch_Notes__c, Mismatch_Type__c (FLS-hidden), Price/Qty_Check_Result__c, PO_Validated__c (formula) | Spec said 7 accessible fields (ghost object) | Spec outdated — object is fully built. Console uses real fields | None — informational |
| Objects | Uploaded_PO_Received__c | Does NOT exist | Verify gate reads it | Verify gates on an actual attached file (ContentDocumentLink count) — stronger than a checkbox | Meg sign-off on the substitution |
| Objects | Pipeline_Bucket__c vs Pipeline_Status__c (§11 item 11) | BOTH exist; also Pipeline_Stage__c (21 values) | Reconcile | Console shows Pipeline_Bucket__c, falls back to Pipeline_Status__c. Stage board lanes ride Status__c per the mockup | Item 11 stays open for which field is canonical |
| Objects | Takeoff_Task__c | Does not exist | Listed for inspection | Not needed by this console | None |
| Objects | Work_Order__c Status picklist | 35 values; all 13 mockup lanes present (NFI = "Need Further Info (NFI)") | 18-stage lifecycle | Board renders the 13 main lanes; sub-statuses as chips | None |
| Objects | Quote__c lifecycle | Trigger enforces forward-only Draft→Sent→Approved; "Approved" = builder acceptance; Total_Amount__c is a rollup | Mockup wanted internal approval before Send | CS internal approval stamps Approved_By__c/Approved_Date__c on the Draft; Send requires the stamp. No picklist changes made | None — behavior matches intent |
| Objects | Catalog of record (§11 item 10) | Item_Catalog__c exists: Unit_Price__c, Standard_Cost__c, BMG_Code__c, Active__c; Quote_Line_Item__c exists with Item_Catalog__c lookup | BMG vs Price Book vs Revenue Cloud open | Quote Builder prices from Item_Catalog__c (active rows) | Confirm Item_Catalog__c as catalog of record |
| Objects | Cases (§11 item 9) | Work_Order__c has Customer Care type, Trigger_Source__c='QI Inspection', QI_Score__c | Standard Case vs CC WO open | Built on Customer Care WOs (where QI automation already lands). Swappable later | Confirm item 9 |
| Validation | Existing PO gates | PO_Approve_Needs_Validation, PO_Mismatch_Needs_Notes, PO_NFI_Needs_Reason, PO_Required_Fields all active | Spec asks for these gates | Already live; console Apex adds verify-file, approve-over-mismatch, approve-before-verify on top | None |
| Validation | CM_Required_On_Customer_Care | Active (non-sysadmin) | — | createCase auto-fills Construction_Manager__c from the community's CM | None |
| Data | Activities on Builder_PO__c | Not enabled — Task.WhatId rejects PO ids | Email/escalation logged to record | Tasks anchor to the Division Account, PO named in subject | Enable activities on Builder_PO__c if direct anchoring wanted |
| Data | Territory backfill (Q-020 / §11 item 13) | 36 communities with null Territory__c (Territory__c is a formula) | 223 nulls flagged | Improved but present. Zone Map ships as the assignment table only; no fake geography | Ops backfill before map layer |
| Data | Record volumes | 39 Builder_PO__c | — | Within limits | None |
| G6 | Zones 1/3/4 FM names | Console hard-blocks zones 1, 3, 4: no FM name rendered anywhere incl. QI trend | BLOCKED pending Ops | Enforced in Apex (BLOCKED_ZONES) | Ops provides names; then unblock |
| G5 | Payments | No payment/credit code anywhere in the console; invoices read-only with GP% | Required | Compliant | Finance informed on Invoices tab scope (§11 item 16) |
| BR step 22 | Cloudscape hold | Invoice__c → LOVING_Work_Order__r.Lennar_Cloudscape_Entry_Complete__c | Surface, never bypass | "Check Cloudscape" explains the hold; writes nothing | None |
| Permissions | LOVING_CSM permission set | Exists in org (not modified) | Pull real set | New LOVING_CS_Console permission set created instead: objects + FLS + LOVING_CS_Console_Edit custom permission + tab. No Lead access granted (§11 item 6 recommendation) | Assign to CSM team when ready |
| Integration | Celigo/QuickBooks | Celigo_Payment_Status__c present on PO/WO | Health check | Read-only; not surfaced in v1 | None |

## Deployed components (validate-then-quick-deploy, 14/14 tests passing)
- `LovingCSConsoleController` (+test) — reads WITH USER_MODE; writes gated by LOVING_CS_Console_Edit; Error_Log__c on every failure
- `lovingCSConsole` LWC — 15 tabs per mockup v6, Field Pro tokens, Agentforce read-and-route rail
- `LOVING_CS_Console` flexipage (incl. mcLOVIN dock), tab, app, permission set, custom permission

## Open Section 11 items still blocking their features
1 (takeoff approval owner), 2 (EPO ceiling — displayed nowhere, not enforced), 3 (GP floor — display-only), 4 (case SLA), 5 (Agentforce grounding — currently client-side over console data only, zero writes), 7 (escalation routing — recipient-neutral Task in place), 12 (Q-010), 13 (territory backfill), 14 (knowledge review — articles render as drafts, not seeded), 15 (G6 names).
