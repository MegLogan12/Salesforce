# Field Manager Warranty Job — Workflow Spec

**Status:** NOT BUILT — type declaration exists, no action or SF object flow  
**Priority:** P1 — Pre-launch (must ship within 30 days of launch)  
**Audit Date:** 2026-06-04

---

## Background

The FM app's `types.ts` defines a `SiteVisitRecord` with `purpose: "Warranty Determination" | "Finished Job Determination" | "Proposal Scope"` and `decision: "Warranty" | "Finished Job" | "Proposal Needed" | "Pending"`. However:

- **No `createWarrantyJob()` action exists** in `domainActions.ts`
- **No Warranty WorkOrder** object or child record type exists in the org
- **No Salesforce automation** backs a warranty determination decision

The only warranty-adjacent fields in the org today are on `WorkOrder`:
- `Is_Finished_Job__c` (Checkbox) — marks the child WorkOrder as a Finished Job
- `Finish_Job_Required__c` (Checkbox) — flags that the original job needs a FJ
- `Finish_Job_Reason__c` (Text) — reason for the FJ

**Warranty is not the same as Finished Job.** A warranty means the original installation had a defect that Loving is responsible to correct at no charge to the builder. A Finished Job means work was incomplete and must return. The FM must distinguish between these and route them differently.

---

## When a Warranty Job Is Needed

A warranty determination happens when:

1. FM conducts a site visit for a lot that has already been closed out (invoiced)
2. FM inspects and finds damage or failure that existed at time of install (not builder/homeowner damage)
3. FM decides: this is Loving's responsibility, not a change order

Common warranty scenarios:
- Plant failure due to incorrect species installed vs PO
- Irrigation system coverage gap that is Loving's installation error
- Sod failure due to incorrect soil prep at install time
- Structural issue (edging, grading) that was incorrect at install

---

## Decision Tree — FM Site Visit

```
FM visits lot →
  FM records checklist items in Site Visit
  FM enters decision:

  DECISION = "Warranty"
    → createWarrantyJob() in domainActions.ts
    → Salesforce: Create child WorkOrder
        Work_Order_Type__c = 'Warranty'
        Parent_Work_Order__c = original WO Id
        Lot__c = original Lot lookup
        Lot_Number__c = original Lot_Number__c
        Community__c = original Community
        Builder_PO__c = original Builder PO
        Foreman__c = assigned Foreman
        Aqua_Community__c = original (if aqua involved)
        Subject = "WARRANTY — " + original WO Subject
        Status = 'New'
    → Notify Division Manager
    → Do NOT block original invoice

  DECISION = "Finished Job"
    → createFinishedJob() (already built)
    → Blocks invoice until FJ closes
    → This path is working today

  DECISION = "Proposal Needed"
    → createQuoteRequest() (not yet built — see FIELD_MANAGER_QUOTE_REQUEST_SPEC.md)
    → Routes to CSM for scope and pricing

  DECISION = "Pending"
    → No action; site visit stays open
    → FM can return to update decision later
```

---

## Required Salesforce Changes

### 1. WorkOrder picklist value

Add `'Warranty'` to `Work_Order_Type__c` picklist on WorkOrder if not already present.

**Verify current picklist values:**
```apex
// Anonymous Apex
Schema.DescribeFieldResult dfr = WorkOrder.Work_Order_Type__c.getDescribe();
for (Schema.PicklistEntry e : dfr.getPicklistValues()) {
    System.debug(e.getLabel() + ' | ' + e.getValue() + ' | active=' + e.isActive());
}
```

### 2. WorkOrder field: `Parent_Work_Order__c`

Check if this field already exists. If not, create:

```xml
<!-- force-app/main/default/objects/WorkOrder/fields/Parent_Work_Order__c.field-meta.xml -->
<?xml version="1.0" encoding="UTF-8"?>
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>Parent_Work_Order__c</fullName>
    <label>Parent Work Order</label>
    <type>Lookup</type>
    <referenceTo>WorkOrder</referenceTo>
    <relationshipLabel>Child Work Orders</relationshipLabel>
    <relationshipName>Child_Work_Orders</relationshipName>
    <required>false</required>
</CustomField>
```

### 3. Quick Action

**Action API Name:** `WorkOrder.LOVING_FM_Create_Warranty_Job`  
**Action Type:** Create a Record  
**Target Object:** WorkOrder  
**Predefined Fields:**
- `Work_Order_Type__c` → `'Warranty'`
- `Parent_Work_Order__c` → `{!WorkOrder.Id}`
- `Lot_Number__c` → `{!WorkOrder.Lot_Number__c}`
- `Status` → `'New'`

**Required on layout:** Subject (pre-filled "WARRANTY — " + parent subject), Description (warranty scope), Foreman__c  
**Hidden:** Revenue_Amount__c, Cost_Amount__c, Gross_Profit__c, Invoice_Number__c

---

## Required App Changes (domainActions.ts)

```typescript
export function createWarrantyJob(
  workspace: FieldManagerWorkspace,
  jobId: string,
  scope: string,
  notes: string
): ActionResult {
  const next = clone(workspace);
  const job = findJob(next, jobId);
  if (!scope.trim()) {
    return { ok: false, message: "Warranty scope description is required.", workspace };
  }
  const photos = job.photos.filter(p => p.status === "complete").length;
  if (photos < 2) {
    return { ok: false, message: "At least 2 accepted photos are required before creating a warranty job.", workspace };
  }
  const childNumber = `${job.workOrder.number}-WTY-${job.activity.length + 1}`;
  job.activity.unshift(event(
    `Warranty job ${childNumber} created. Scope: ${scope}. Notes: ${notes || "None"}. Photos: ${photos}. Division Manager notified.`,
    next.currentUser.name,
    "record-update"
  ));
  return {
    ok: true,
    message: `Warranty WorkOrder ${childNumber} created and linked to ${job.workOrder.number}. Division Manager has been notified.`,
    workspace: next
  };
}
```

This must also call the Salesforce API to insert the child WorkOrder. Wire via `fieldManagerRepository.ts`.

---

## Notification Requirements

When `createWarrantyJob()` succeeds:

| Recipient | Channel | Message |
|---|---|---|
| Division Manager | Salesforce in-app notification + email | "Warranty job created for Lot {LotNumber} by FM {FMName}. Review required." |
| FM | In-app confirmation | "Warranty WorkOrder created. Division Manager notified." |
| Foreman (if assigned) | Optional push notification | "Warranty job created for your lot. Expect return visit." |

---

## Gate Rules

- FM cannot close out the **original** WorkOrder if a warranty child WorkOrder is open
- Warranty child WorkOrder has its own QI + closeout flow (same gates as a standard install)
- Invoice for **original** WorkOrder is NOT blocked by warranty (warranty is Loving's cost, not builder's missing payment)
- Invoice for warranty child WorkOrder: $0 or internal cost only — must not generate a builder-facing invoice

---

## FM Training Notes

The FM must understand the difference before launch:

| Decision | Creates | Blocks Original Invoice? | Who Pays? |
|---|---|---|---|
| Warranty | Child WorkOrder (Warranty type) | No | Loving (internal cost) |
| Finished Job | Finish_Job__c record | Yes — until FJ closes | Builder (billed after FJ close) |
| Proposal Needed | Quote_Request__c | No | Builder (after quote approved) |

If the FM can't distinguish these three decisions, the close-out flow will be corrupted within the first week of field use.
