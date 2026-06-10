# Field Manager Warranty Job Spec

**Version:** 1.0  
**Date:** 2026-06-05  
**Object:** `Warranty_Record__c` (confirmed in org, fields: WorkOrder__c, Case__c, Homeowner_Account__c, Status__c)

---

## Purpose

Allow a Field Manager to initiate warranty or return work from the field when:
- Completed work has failed
- A customer or builder has a valid post-completion issue
- A QI inspection identified warranty-grade failures

The FM captures the issue and routes it to Customer Success. **FM does not close warranty work, make coverage decisions, or mark jobs billable without CS approval.**

---

## Existing Architecture (Confirmed)

`Warranty_Record__c` fields confirmed in org:
- `WorkOrder__c` — Lookup to original completed WorkOrder
- `Case__c` — Lookup to related Customer Care Case
- `Homeowner_Account__c` — Lookup to homeowner Account
- `Status__c` — Status picklist

**Additional fields may need to be added (see below). Verify existing fields before deploying.**

---

## Recommended Status Path

```
Field Reported → Submitted to CS → Under Review → Site Visit Scheduled → 
Warranty Approved → Work Scheduled → Work Complete → Closed
```

**Alternative statuses:**
- `Denied — Not Covered`
- `Denied — Customer Fault`
- `Duplicate`
- `Pending Additional Info`

**FM can only set:** `Field Reported`, `Submitted to CS`  
**FM cannot set:** `Warranty Approved`, `Denied`, or billing decisions

---

## Warranty Categories

| Category | When to Use |
|---|---|
| Plant material warranty | Plant died or failed within warranty period |
| Sod issue | Sod failure, disease, poor establishment |
| Irrigation issue | Irrigation system not functioning as installed |
| Drainage issue | Drainage solution failed or made worse |
| Hardscape issue | Pavers, walls, or hardscape settled, cracked, or failed |
| Settlement | Grade settled or soil movement affecting finished surface |
| Washout / erosion | Erosion or washout on completed area |
| Cleanup issue | Job site cleanup was insufficient |
| Damage | LOVING crew damaged property |
| Builder punch issue | Builder-identified deficiency in completed work |
| Homeowner complaint | Homeowner dissatisfied with quality or scope |
| Other | Use with required description |

---

## Fields to Add to `Warranty_Record__c`

Confirm these fields do not already exist before deploying.

| Field API Name | Type | Required | Description |
|---|---|---|---|
| `FM__c` | Lookup(User) | Yes | Field Manager who initiated the record |
| `Lot__c` | Lookup(Lot__c) | No | The Lot/Site record |
| `Service_Appointment__c` | Lookup(ServiceAppointment) | No | Original SA if available |
| `Category__c` | Picklist | Yes | Warranty category from list above |
| `Date_Original_Work_Completed__c` | Date | Yes | When original work was completed |
| `Issue_Description__c` | LongTextArea | Yes | FM description of the issue |
| `Reported_By__c` | Picklist | Yes | Field Manager / Homeowner / Builder / Other |
| `Severity__c` | Picklist | Yes | Low / Medium / High / Critical |
| `FM_Coverage_Recommendation__c` | Picklist | No | LOVING responsible / Homeowner responsible / Builder responsible / Unknown |
| `FM_Notes__c` | LongTextArea | No | Additional field notes |
| `Photos_Attached__c` | Checkbox | Auto | True if ContentDocumentLinks exist |
| `Submit_Date__c` | Date | Auto | Date FM submitted |
| `CS_Assigned_To__c` | Lookup(User) | No | CS owner — set by CS |
| `CS_Notes__c` | LongTextArea | No | CS notes — FM read-only |
| `Coverage_Decision__c` | Picklist | No | CS sets: Covered / Not Covered / Partial / Pending |
| `Billable__c` | Checkbox | No | CS sets: true if customer is billed |
| `Billable_Reason__c` | LongTextArea | No | CS sets if billable |

### Fields FM Cannot Edit (FLS: Read Only for FM Profile)

- `Coverage_Decision__c`
- `Billable__c`
- `Billable_Reason__c`
- `CS_Assigned_To__c`
- `CS_Notes__c`
- Any financial field added to this object

---

## FM Screen Design

### Step 1: Auto-Fill Context
```
Work Order: [auto-filled from current WO]
Lot:        [auto-filled from WO.Lot__c]
Account:    [auto-filled from WO.Account]
Contact:    [auto-filled if exists]
```

### Step 2: Warranty Category
```
What type of warranty issue is this?
○ Plant material warranty
○ Sod issue
○ Irrigation issue
○ Drainage issue
○ Hardscape issue
○ Settlement
○ Washout / erosion
○ Cleanup issue
○ Damage
○ Builder punch issue
○ Homeowner complaint
○ Other (requires notes)
```

### Step 3: Issue Description
```
Describe the issue (required):
[Text area — min 20 characters]
"Be specific. Customer Success needs enough detail to assess coverage and 
schedule a site visit."

When was the original work completed? (required):
[Date picker]

Who reported this issue?
○ I identified it (FM)
○ Homeowner
○ Builder
○ Other
```

### Step 4: Severity
```
How severe is this issue?
○ Low — cosmetic, low urgency
○ Medium — functional issue, needs attention within 2 weeks
○ High — significant failure, needs attention within 1 week
○ Critical — safety or major property concern, immediate

Your coverage opinion (optional — CS decides):
○ LOVING responsible
○ Homeowner responsible
○ Builder responsible
○ Unknown / needs review
```

### Step 5: Photos (Required for most categories)
```
Required for: Sod issue, Irrigation, Drainage, Hardscape, Damage, Settlement, Washout
Recommended for: All others

[+ Add Photo] → camera or gallery
Category: [Warranty issue / Before / Damage / Drainage / Other]
```

### Step 6: Notes
```
Additional notes for Customer Success:
[Text area — optional]
```

### Confirmation
```
Warranty Report Submitted
Customer Success has been notified.
A site visit may be scheduled to assess coverage.
Record ID: WR-XXXXXXXX
```

---

## System Actions on Submit

1. Create `Warranty_Record__c` with `Status__c = 'Submitted to CS'`
2. If `Case__c` is provided or auto-created: link `Case.Type = 'Warranty'`
3. Create `ContentDocumentLink` for any photos
4. Create `Task` for Customer Success: "Review warranty report [WR-ID] from [FM Name] on [WO] — [Category]"
5. Post Chatter: "@[CS Queue] Warranty report submitted: [Category] on Lot [Number], Work Order [WO Number]"

---

## Decision Logic

| Condition | FM Action | System Creates | CS Receives |
|---|---|---|---|
| FM identifies sod failure within 30 days | Create Warranty Job (category: Sod issue) | Warranty_Record__c + Task | Record + photos + severity |
| QI fails — rework needed (LOVING scope) | Create Finished Job instead | Child WorkOrder | Scheduling queue |
| QI fails — plant died on arrival | Create Warranty Job (category: Plant material) | Warranty_Record__c | Record + photos |
| Customer calls about drainage after job | Create Warranty Job (category: Drainage issue) | Warranty_Record__c | Record + FM notes on original install |
| Builder reports punch item | Create Change Order (not Warranty) if scope change; Warranty if workmanship | Change_Order__c OR Warranty_Record__c | Depends on type |
| FM damaged property | Create Issue (Crew damage) — NOT a Warranty Job | Schedule_Issue__c | Escalation to Regional Manager first |

---

## Warranty vs. Finished Job Decision Guide

```
Was the original contracted scope completed?
    │
    ├── NO → Create Finished Job (child WorkOrder, No Charge billing)
    │
    └── YES — Was there a failure or defect after completion?
                │
                ├── YES, within warranty period → Create Warranty Job
                │
                ├── YES, but customer-caused → Create Warranty Job with 
                │   FM recommendation: Homeowner responsible
                │
                └── NO, but customer wants something NEW → Create Quote Request
```

---

## Guardrails

**FM CANNOT:**
- Set `Coverage_Decision__c`
- Set `Billable__c = true`
- Create a final quote from a warranty record directly
- Close or mark warranty work complete (CS owns this)
- Mark denied

**FM CAN:**
- Submit a new Warranty Record from any active or recently closed WorkOrder
- Add notes and photos
- View status updates
- Tag a Warranty Record as High or Critical severity (triggers escalation to CS)
