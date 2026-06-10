# Field Manager Quote Request Spec

**Version:** 1.0  
**Date:** 2026-06-05  
**Object:** `UMB_Quote_Request__c` (confirmed in org)

---

## Purpose

Allow a Field Manager to capture added or changed scope in the field and route it to Customer Success for pricing and approval — without letting the FM set price, GP, discount, or finalize the quote.

---

## Existing Architecture (Confirmed)

`UMB_Quote_Request__c` is a custom object in the org with these confirmed fields:
- `Customer_Email__c`
- `Customer_Phone__c`
- `Fire_Pla__c` (Fire Place/Pit add-on)
- `Grill_Island__c`
- `Irrigation_Upgrade__c`
- `Landscape_Enhancement__c`
- `Pavers__c`

**Current use case:** Add-on scope capture for builder/homeowner upgrades.  
**New use case (FM):** Field-originated scope requests and change order requests from active Work Orders.

---

## Recommended Status Path

```
Field Request → Submitted to Customer Success → Under Pricing Review → Approved for Customer → Returned to Field Manager → Canceled / Duplicate
```

**FM can only set:** Field Request, Submitted, Returned notes  
**FM cannot set:** Under Pricing Review, Approved, or any pricing fields

---

## Fields to Add to `UMB_Quote_Request__c`

These fields need to be created if they do not exist. Check before deploying.

### FM Context Fields (New)

| Field API Name | Type | Required | Description |
|---|---|---|---|
| `Work_Order__c` | Lookup(WorkOrder) | Yes | The active Work Order this request relates to |
| `Lot__c` | Lookup(Lot__c) | Yes | The Lot/Site record |
| `Service_Appointment__c` | Lookup(ServiceAppointment) | No | If SA is the scheduling context |
| `FM__c` | Lookup(User) | Yes | Field Manager submitting the request |
| `Submit_Date__c` | Date | Auto | Date FM submitted |
| `Request_Type__c` | Picklist | Yes | Scope Change / Drainage Fix / Utility Conflict / Warranty Assessment / Additional Install / Other |
| `Customer_Type__c` | Picklist | Yes | Homeowner / Builder / Internal / Warranty Review |
| `Scope_Description__c` | LongTextArea | Yes | FM's field description of what is needed |
| `Reason__c` | LongTextArea | Yes | Why is this request needed |
| `Measured_Sqft__c` | Number | No | FM-measured square footage if applicable |
| `Measured_Linear_Ft__c` | Number | No | FM-measured linear footage |
| `Drainage_Impact__c` | Checkbox | No | Does this involve drainage |
| `Utility_Impact__c` | Checkbox | No | Does this involve utilities or 811 |
| `Access_Issue__c` | Checkbox | No | Is access a constraint |
| `FM_Billable_Recommendation__c` | Picklist | No | Billable / Non-Billable / Warranty / Unknown |
| `FM_Notes__c` | LongTextArea | No | Additional field notes |
| `Urgency__c` | Picklist | No | Routine / Within 1 week / Same week / Immediate |
| `Status__c` | Picklist | Yes | Status path above |
| `CS_Assigned_To__c` | Lookup(User) | No | Customer Success owner — set by CS on intake |
| `CS_Notes__c` | LongTextArea | No | Customer Success notes — FM read-only |
| `CS_Decision__c` | Picklist | No | Approved / Rejected / Pending / Returned — CS sets only |
| `Photos_Attached__c` | Checkbox | Auto | True if ContentDocumentLinks exist |

### Fields FM Cannot Edit (FLS: Read Only for FM Profile)

- Any pricing field (`Price__c`, `Cost__c`, `GP__c`, `Discount__c`)
- `CS_Assigned_To__c`
- `CS_Notes__c`
- `CS_Decision__c`
- `Approved_By__c`
- `Approved_Date__c`

---

## FM Screen Design

### Step 1: Context Auto-Fill
```
Work Order: [auto-filled from current WO]
Lot:        [auto-filled from WO.Lot__c]
Account:    [auto-filled from WO.Account]
Contact:    [auto-filled from WO.Contact if exists]
```

### Step 2: Request Type + Customer Type
```
What type of request is this?
○ Scope Change
○ Drainage Fix
○ Utility Conflict
○ Warranty Assessment
○ Additional Install
○ Other

Who is the customer?
○ Homeowner
○ Builder
○ Internal
○ Warranty Review
```

### Step 3: Scope Description
```
Describe what is needed (required):
[Text area — min 20 characters]
"Add a short scope note before submitting. Customer Success needs enough 
detail to price or route this correctly."

Why is this needed? (required):
[Text area]
```

### Step 4: Measurements (optional but encouraged)
```
Measured square footage: ____
Measured linear feet: ____
[ ] Drainage impact
[ ] Utility/811 impact
[ ] Access constraint
```

### Step 5: Urgency + FM Recommendation
```
Urgency: [Routine / Within 1 week / Same week / Immediate]
Billing recommendation (your opinion only — CS decides): 
[Billable / Non-Billable / Warranty / Unknown]
Additional notes: [text area]
```

### Step 6: Photos
```
Attach supporting photos (category required):
[+ Add Photo] → opens camera or gallery
Category: [Change Order proof / Drainage / Access / Before / Other]
```

### Confirmation Screen
```
Quote Request Submitted
Customer Success has been notified.
You will receive a status update when pricing is complete.
Request ID: QR-XXXXXXXX
```

---

## System Actions on Submit

1. Create `UMB_Quote_Request__c` with `Status__c = 'Submitted to Customer Success'`
2. Create `ContentDocumentLink` records for any attached photos
3. Create `Task` for Customer Success: "Review quote request [QR-ID] from [FM Name] on [WO]"
4. Post Chatter on `UMB_Quote_Request__c`: "@[CS Queue] New field quote request from [FM] on Lot [Lot Number]"
5. Update `WorkOrder.Site_Visit_Quote_Link__c` with the new record ID

---

## Validation Rules

| Condition | Error Message |
|---|---|
| `Scope_Description__c` is blank | Add a short scope note before submitting. Customer Success needs enough detail to price or route this correctly. |
| `Work_Order__c` is blank | Select the Work Order this request is for. |
| `Lot__c` is blank | Confirm the Lot/Site record before submitting. |
| `Request_Type__c` is blank | Select the type of request. |
| `Status__c` = Approved AND current user is not CS team | You cannot approve quote requests. This is a Customer Success action. |

---

## Guardrails

**FM CANNOT:**
- Set `CS_Decision__c`
- Set `Approved_By__c`
- Edit any pricing field
- Change status to `Approved for Customer`
- Create a final quote directly from this record

**FM CAN:**
- Submit
- Add notes while `Status__c = Returned to Field Manager`
- View all fields as read-only once submitted
- Upload photos at any stage

---

## Change Order vs. Quote Request

| Scenario | Use `UMB_Quote_Request__c` | Use `Change_Order__c` |
|---|---|---|
| FM identifies new scope on active job | ✅ | Maybe |
| Formal change order with cost/revenue impact | No | ✅ |
| Builder-requested change with contract implication | No | ✅ |
| Add-on upgrade (fire pit, pavers, irrigation) | ✅ | No |
| FM measuring new drainage scope | ✅ | No |

If both objects are needed, `Change_Order__c` has a `Quote__c` lookup — use `UMB_Quote_Request__c` as the intake and `Change_Order__c` as the approved output.
