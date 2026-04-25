# LOVING Production Install — Salesforce DX Package
## Deploy Instructions & Schedule Setup

---

## WHAT'S IN THIS PACKAGE

| Component Type | Count | Notes |
|---|---|---|
| Custom Objects | 5 | QI_Inspection__c, QI_Line_Item__c, Finish_Job__c, Time_Entry__c, Aqua_Inventory__c |
| WorkOrder Custom Fields | 84 | All 18-stage fields, GP, RTN, Measuring Cup |
| Account Custom Fields | 31 | Lot + Community + Builder Regional fields |
| Flows | 11 | 1 Orchestrator + 6 sub-flows + 3 scheduled + 1 Takeoff-to-WO |
| Apex Classes | 7 | Trigger handler, services, schedulers, test class |
| Apex Triggers | 1 | LOVING_WorkOrderTrigger on WorkOrder |
| Validation Rules | 8 | All enforced — see section below |

---

## PREREQUISITES — CONFIRM BEFORE DEPLOYING

- [ ] Salesforce Field Service (FSL) licensed and installed
- [ ] `sf` CLI installed and authenticated: `sf auth web login`
- [ ] VS Code with Salesforce Extension Pack
- [ ] Account Record Types created: Builder_National, Builder_Regional, Community, Lot
- [ ] WorkOrder Status picklist values match exactly (see STATUS VALUES below)
- [ ] QA sandbox available for test deploy before production push

---

## STATUS VALUES — ADD THESE TO WorkOrder.Status PICKLIST

Add these values to the WorkOrder Status picklist in Setup before deploying
(Flows and validation rules reference these exact strings):

```
New
Lead: New
Lead: Working
Lead Converted
Community Activated
Pending Takeoff
Takeoff Scheduled
Takeoff Complete
Finalize Schedule
Scheduled
Site Readiness Check
In Progress
Completed (Field Complete)
Pending Closeout Approval
Need Further Info
Approved
QI Inspection Open
Invoiced
Paid
Closed
Cancelled
On Hold
```

---

## DEPLOY STEPS

### Step 1 — Authenticate
```bash
sf auth web login --alias loving-prod
# or for sandbox:
sf auth web login --alias loving-sandbox --instance-url https://test.salesforce.com
```

### Step 2 — Validate (dry run — ALWAYS do this first)
```bash
cd /path/to/LOVING-SF
sf project deploy validate \
  --source-dir force-app \
  --target-org loving-sandbox \
  --test-level RunSpecifiedTests \
  --tests LOVING_WorkOrderTriggerHandlerTest
```

### Step 3 — Deploy to sandbox
```bash
sf project deploy start \
  --source-dir force-app \
  --target-org loving-sandbox \
  --test-level RunSpecifiedTests \
  --tests LOVING_WorkOrderTriggerHandlerTest
```

### Step 4 — Run tests
```bash
sf apex run test \
  --class-names LOVING_WorkOrderTriggerHandlerTest \
  --target-org loving-sandbox \
  --result-format human \
  --wait 10
```

### Step 5 — Deploy to production (after sandbox passes)
```bash
sf project deploy start \
  --source-dir force-app \
  --target-org loving-prod \
  --test-level RunSpecifiedTests \
  --tests LOVING_WorkOrderTriggerHandlerTest
```

---

## POST-DEPLOY SETUP — SCHEDULE ALL APEX JOBS

Run these in the Developer Console (Setup → Developer Console → Execute Anonymous):

```apex
// 1. Bucket Engine — daily 5:00 AM
System.schedule(
    'LOVING Bucket Engine 5AM',
    '0 0 5 ? * * *',
    new LOVING_BucketEngineScheduler()
);

// 2. Health Check Prompt — daily 2:00 PM weekdays
System.schedule(
    'LOVING Health Check 2PM',
    '0 0 14 ? * MON-FRI *',
    new LOVING_HealthCheckScheduler()
);

// 3. Health Check Escalation — daily 3:00 PM weekdays
System.schedule(
    'LOVING Health Check Escalation 3PM',
    '0 0 15 ? * MON-FRI *',
    new LOVING_HealthCheckEscalationScheduler()
);

// 4. Takeoff Escalation — daily 9:00 AM
System.schedule(
    'LOVING Takeoff Escalation 9AM',
    '0 0 9 ? * MON-FRI *',
    new LOVING_TakeoffEscalationScheduler()
);

// 5. QI Escalation — daily 8:00 AM
System.schedule(
    'LOVING QI Escalation 8AM',
    '0 0 8 ? * MON-FRI *',
    new LOVING_QIEscalationScheduler()
);
```

Verify all 5 jobs appear in Setup → Scheduled Jobs.

---

## POST-DEPLOY SETUP — ACTIVATE FLOWS

All flows deploy as Active. If any deploy as Inactive, activate in:
Setup → Flows → [Flow Name] → Activate

Flows to verify Active:
- LOVING_PI_Orchestrator
- LOVING_Takeoff_To_WO_Creation
- LOVING_Bucket_Engine
- LOVING_Health_Check_Daily
- LOVING_Takeoff_Escalation
- All 6 sub-flows (LOVING_PI_*)

---

## VALIDATION RULES — WHAT THEY BLOCK

| Rule | Triggers On | What It Prevents |
|---|---|---|
| Takeoff_Required_Before_Scheduling | Status → Finalize Schedule or Scheduled | WO scheduled without completed takeoff |
| Site_Readiness_Required | Status → In Progress | Crew dispatched without site readiness pass |
| Red_Flag_Notes_Required | Health Check → Red | Red health check without explanation |
| Closeout_Photos_Required | Status → Pending Closeout Approval | Closeout submitted without photos |
| Closeout_Quantities_Required | Status → Pending Closeout Approval | Closeout submitted without quantity confirmation |
| NFI_Notes_Required | Status → Need Further Info | NFI set without specifying what's needed |
| QI_Escalation_On_Red_Hold | QI_Status__c → FM QI Review (Red Hold) | Red Hold set without submitted QI |
| GP_Hard_Floor_Invoice_Block | Invoice Number entered | Invoice creation at GP < 22% |

---

## FSL CONFIGURATION (Manual — in Setup)

These must be configured manually after deploy. FSL configuration cannot be deployed via metadata.

1. **Operating Hours**: Create LOVING Operating Hours — Mon-Fri 6:30 AM - 5:00 PM Eastern
2. **Service Territory**: Create "Charlotte Metro" territory, assign 309 Morningside Rd as service depot
3. **Work Types**: Create "Production Install" Work Type
   - Estimated Duration: pulled from Goal_Hours__c (use Field Expression)
   - Travel Mode: Driving
4. **Scheduling Policy**: Create "LOVING Production Install" policy
   - Priority: High
   - Minimize Travel
   - Respect required skills
5. **Resources**: Assign FM users as Service Resources (Field Technician type)
6. **Zones**: Map Zones 1-15 to service territory member areas

---

## QUICKBOOKS / CELIGO INTEGRATION

The nightly Celigo sync reads Invoice_Number__c on WorkOrder to match QB invoices.
After deploy, confirm:
- Celigo recipe is pointing to WorkOrder object (not Opportunity)
- Payment_Received__c is mapped as the sync field for payment confirmation
- Payment_Date__c maps to QB payment date

Contact your Celigo admin to update the recipe field mappings.

---

## KNOWN GAPS / PHASE 2 ITEMS

| Item | Priority | Notes |
|---|---|---|
| SupplyPro API integration | P0 | PO ingestion from DR Horton. Requires Celigo or MuleSoft recipe |
| WorkOrder Line Item creation from Takeoff | P1 | Currently WO creates without line items. Need to map BMG package → WOLI |
| Rippling API → Time_Entry__c sync | P1 | Actual hours data source for Measuring Cup |
| FSL auto-scheduling from Dispatch Console | P1 | FSL config above must be complete first |
| Account Record Type creation | P0 | Must create 4 RTs before deploying |
| GP Cost Book integration | P1 | Cost_Amount__c currently not auto-populated; requires PriceBook2 (cost) setup |
| QI_Line_Item__c creation from WOLI | P1 | Currently no WOLI on WO — QI line items are blank shells |
| Aqua community service day UI | P2 | Aqua_Service_Days__c field needs a Community management page |

---

## FILE STRUCTURE

```
LOVING-SF/
├── sfdx-project.json
├── manifest/package.xml
├── force-app/main/default/
│   ├── objects/
│   │   ├── WorkOrder/fields/         (84 custom fields)
│   │   ├── Account/fields/           (31 custom fields)
│   │   ├── QI_Inspection__c/
│   │   ├── QI_Line_Item__c/
│   │   ├── Finish_Job__c/
│   │   ├── Time_Entry__c/
│   │   └── Aqua_Inventory__c/
│   ├── flows/                        (11 flows)
│   ├── classes/                      (7 Apex files + meta)
│   ├── triggers/                     (1 trigger + meta)
│   └── validationRules/WorkOrder/    (8 rules)
└── README.md                         (this file)
```

---

## QUESTIONS / ISSUES

Contact: Megan Logan, COO, LOVING Outdoor Living
Build version: 1.0 — April 2026
Salesforce API version: 62.0
