# Field Manager Quote Request — Object & Workflow Spec

**Status:** NOT BUILT — `Quote_Request__c` does not exist in the org  
**Priority:** P0 — Launch blocker  
**Audit Date:** 2026-06-04

---

## Background

The Field Manager identifies scope that falls outside the original PO during takeoff or site inspection. Today there is no structured path to capture this — it either gets missed, handled by phone call, or entered as a freeform note. The `Quote_Request__c` object must be created before any FM quote request flow can be built in the app or in Salesforce.

The FM may describe the scope and attach photos. The FM may **never** set, edit, or approve a final price. Pricing flows through CSM → Division Account only.

---

## Option A: Create `Quote_Request__c` Custom Object (Recommended)

### Object Configuration

| Setting | Value |
|---|---|
| Object Label | Quote Request |
| Object API Name | `Quote_Request__c` |
| Parent Object | WorkOrder (Master-Detail or Lookup) |
| Lookup Field API Name | `Work_Order__c` |
| Record Name | Auto-number: `QR-{0000}` |
| Sharing | Controlled by Parent |
| Activities | Yes |
| Reports | Yes |

### Fields

| Field Label | API Name | Type | FM Access | Notes |
|---|---|---|---|---|
| Work Order | `Work_Order__c` | Lookup(WorkOrder) | Read | Parent lookup; required |
| Scope Description | `Scope_Description__c` | Long Text Area (32768) | Edit | Required on create |
| Request Type | `Request_Type__c` | Picklist | Edit | Values: Scope Outside PO / Change Order / Warranty Proposal / Aqua Addition |
| Requested By | `Requested_By__c` | Lookup(User) | Read (auto-set) | Defaults to running user (FM) on create |
| Status | `Status__c` | Picklist | Read | Values: New / Sent to CSM / Approved / Rejected / On Hold |
| Quote Amount | `Quote_Amount__c` | Currency | **Read-only to FM** | Set by CSM; FM cannot edit |
| Builder Approval | `Builder_Approval__c` | Checkbox | **Read-only to FM** | Set by CSM/Builder; FM cannot check |
| Builder PO Reference | `Builder_PO_Ref__c` | Text(50) | Read | Populated from WorkOrder.PO_Number__c on create |
| Lot Number | `Lot_Number__c` | Text(20) | Read | Populated from WorkOrder.Lot_Number__c on create |
| Photos Attached | `Photos_Attached__c` | Number | Read | Count of attached files; do not allow zero on submit |
| CSM Notes | `CSM_Notes__c` | Long Text Area | **Read-only to FM** | Internal CSM field |
| Decision Date | `Decision_Date__c` | Date | Read | Set by CSM when Status changes to Approved/Rejected |
| FM Notes | `FM_Notes__c` | Long Text Area | Edit | FM can add context at any time |

### Permission Set Rules

The `LOVING_Field_Manager_App_User` permission set must be granted:
- Create, Read on `Quote_Request__c`
- Edit on: `Scope_Description__c`, `Request_Type__c`, `FM_Notes__c`
- **No Edit** on: `Quote_Amount__c`, `Builder_Approval__c`, `Status__c`, `CSM_Notes__c`, `Decision_Date__c`

CSM / Inside Sales users must have full CRUD.

### Validation Rules

```
// FM cannot submit without at least one photo
Quote_Request__c:
  Rule: Photos_Attached__c = 0 AND Status__c != 'New'
  Error: "Attach at least one photo before submitting a quote request."

// FM cannot edit price
// Enforced at field-level permission, not validation rule.
// But add this as a belt-and-suspenders check:
  Rule: ISCHANGED(Quote_Amount__c) AND NOT($Permission.LOVING_CSM_User)
  Error: "Only a CSM can set the quote amount."
```

### Automation

**Flow: Quote_Request_New_to_CSM**
- Trigger: Record Created on Quote_Request__c where Status__c = 'New'
- Action 1: Send email to CSM assigned to the parent WorkOrder's Division Account
- Action 2: Create Task on WorkOrder for CSM: "Review Quote Request {QR-XXXX}"
- Action 3: Send in-app notification to FM: "Quote request submitted. CSM will respond within 2 business days."

**Flow: Quote_Request_Decision_to_FM**
- Trigger: Status__c changes to Approved or Rejected
- Action 1: Set Decision_Date__c = TODAY()
- Action 2: Send in-app notification to FM with CSM decision and notes

---

## Option B: Case Object with RecordType "Quote Request"

Use if `Quote_Request__c` creation is blocked by deployment timeline.

| Setting | Value |
|---|---|
| Object | Case |
| RecordType | Quote Request (create new RecordType) |
| Page Layout | FM Quote Request Layout (create new) |
| Case Origin | Field Manager App |
| Account | WorkOrder's parent Account |

**Tradeoffs vs Option A:**
- Pro: No new object deployment needed; Case email-to-case routing already configured
- Con: Cases mix with support queue; no Master-Detail to WorkOrder (must use lookup + required validation); `Quote_Amount__c` must be added as a custom field on Case object (affects all Cases)
- **Recommendation:** Use Option A. The Case object is not purpose-built for this workflow and will create operational confusion in the support queue.

---

## App-Side Implementation (domainActions.ts)

Add the following function to `domainActions.ts`:

```typescript
export function createQuoteRequest(
  workspace: FieldManagerWorkspace,
  jobId: string,
  requestType: string,
  scopeDescription: string,
  notes: string
): ActionResult {
  const next = clone(workspace);
  const job = findJob(next, jobId);
  if (!scopeDescription.trim()) {
    return { ok: false, message: "Scope description is required.", workspace };
  }
  const photos = job.photos.filter(p => p.status === "complete").length;
  if (photos < 1) {
    return { ok: false, message: "At least one accepted photo is required before submitting a quote request.", workspace };
  }
  const qrNumber = `QR-${String(job.activity.length + 1).padStart(4, "0")}`;
  job.activity.unshift(event(
    `Quote request ${qrNumber} submitted. Type: ${requestType}. Scope: ${scopeDescription}. Notes: ${notes || "None"}. Photos attached: ${photos}.`,
    next.currentUser.name,
    "record-update"
  ));
  return {
    ok: true,
    message: `Quote request ${qrNumber} submitted to CSM. You will be notified when a decision is made.`,
    workspace: next
  };
}
```

This function must also call the Salesforce API to insert a `Quote_Request__c` record. Wire via `fieldManagerRepository.ts`.

---

## Salesforce Quick Action

Once the object is deployed, create:

**Action API Name:** `WorkOrder.LOVING_FM_Request_Quote`  
**Action Type:** Create a Record  
**Target Object:** `Quote_Request__c`  
**Predefined Fields:**
- `Work_Order__c` → `{!WorkOrder.Id}`
- `Requested_By__c` → `{!$User.Id}`
- `Status__c` → `New`
- `Lot_Number__c` → `{!WorkOrder.Lot_Number__c}`
- `Builder_PO_Ref__c` → `{!WorkOrder.PO_Number__c}`

**Required on the layout:** Scope_Description__c, Request_Type__c, FM_Notes__c  
**Hidden from layout:** Quote_Amount__c, Builder_Approval__c, CSM_Notes__c, Status__c (pre-set), Decision_Date__c

---

## Package.xml Entry (when ready to deploy)

```xml
<types>
  <members>Quote_Request__c</members>
  <name>CustomObject</name>
</types>
<types>
  <members>Quote_Request__c.Work_Order__c</members>
  <members>Quote_Request__c.Scope_Description__c</members>
  <members>Quote_Request__c.Request_Type__c</members>
  <members>Quote_Request__c.Requested_By__c</members>
  <members>Quote_Request__c.Status__c</members>
  <members>Quote_Request__c.Quote_Amount__c</members>
  <members>Quote_Request__c.Builder_Approval__c</members>
  <members>Quote_Request__c.Builder_PO_Ref__c</members>
  <members>Quote_Request__c.Lot_Number__c</members>
  <members>Quote_Request__c.Photos_Attached__c</members>
  <members>Quote_Request__c.CSM_Notes__c</members>
  <members>Quote_Request__c.Decision_Date__c</members>
  <members>Quote_Request__c.FM_Notes__c</members>
  <name>CustomField</name>
</types>
<types>
  <members>WorkOrder.LOVING_FM_Request_Quote</members>
  <name>QuickAction</name>
</types>
```
