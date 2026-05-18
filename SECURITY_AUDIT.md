# LOVING Salesforce Security & Code Audit
**Scope:** Production Install v1.0 — API 62.0  
**Date:** May 2026  
**Branch:** claude/continue-audit-session-iI2lE

---

## SESSION SETTINGS (Org-Level)

### FINDING 1 — MFA Not Enforced for Username/Password Login  
**Severity: HIGH**

The screenshot shows `Multi-Factor Authentication` in the **High Assurance** column while `Username Password` and `Delegated Authentication` remain in **Standard**. This means users who log in with a username and password are not required to complete MFA.

**Current state:**
- Standard: Username Password, Delegated Authentication (+ 12 marketing/SSO connectors)
- High Assurance: Multi-Factor Authentication only

**Risk:** Any user whose password is compromised can log in with no MFA challenge. This is the most common initial access vector in Salesforce breaches.

**Fix:**
1. Setup → Session Settings → Session Security Levels
2. Select `Username Password` in the Standard list → click **Add** to move it to High Assurance
3. Select `Delegated Authentication` → move to High Assurance
4. Optionally enforce at profile/permission set level via: Setup → Users → Permission Sets → Session Activation Required

Salesforce's built-in MFA enforcement (released in v58+) can also be activated via: Setup → Identity → MFA Management → **Enable MFA for All Users**.

---

### FINDING 2 — Excessive Marketing Platform Connectors Enabled  
**Severity: LOW / INFORMATIONAL**

The Standard security level has 10+ third-party marketing/social platform connectors enabled (LinkedIn, Facebook, TikTok, Twitter/X, Google Ads, Microsoft Bing, Confluence, etc.). Each one is an OAuth integration point.

**Risk:** Unused connectors are unnecessary attack surface. If any of these services are compromised or credentials are stolen, they provide an authentication path into the org.

**Fix:** Audit which connectors are actively used. Disable any not in production use via Setup → Connected Apps.

---

## APEX CODE AUDIT

### FINDING 3 — All Service Classes Use `without sharing`  
**Severity: HIGH**

Every Apex class that performs DML or SOQL is declared `without sharing`:

| Class | Declaration |
|---|---|
| `LOVING_WorkOrderTriggerHandler` | `public without sharing` |
| `LOVING_MeasuringCupService` | `public without sharing` |
| `LOVING_AquaTicketService` | `public without sharing` |
| `LOVING_BucketEngineScheduler` | `global without sharing` |
| `LOVING_BucketEngineService` | `public without sharing` |

`without sharing` ignores all org-wide defaults and sharing rules. **Every user who can trigger these classes can read and write any WorkOrder, Account, QI_Inspection, Finish_Job, and financial data (Revenue_Amount__c, Cost_Amount__c, Gross_Margin_Pct__c) regardless of their profile or sharing configuration.**

This is particularly risky for `LOVING_MeasuringCupService`, which reads and writes GP and revenue figures, and `LOVING_BucketEngineService`, which reads all active Lot accounts org-wide.

**Fix:** Change trigger handlers to `inherited sharing` (respects the caller's sharing context) unless there's a documented operational reason. Change the scheduled/service classes to `with sharing` unless the scheduled job must run system-wide by design (in which case document the reason explicitly).

```apex
// Preferred for trigger handlers:
public inherited sharing class LOVING_WorkOrderTriggerHandler { ... }

// Acceptable for scheduled jobs that must see all records:
// Add a comment explaining why without sharing is required
global without sharing class LOVING_BucketEngineScheduler implements Schedulable { ... }
```

---

### FINDING 4 — Dead / Broken SOQL in `handleStatusToNFI`  
**Severity: MEDIUM**

`LOVING_WorkOrderTriggerHandler.cls` lines 373–376 contain invalid Apex syntax that would fail to compile in a real org:

```apex
// THIS WILL NOT COMPILE — .stream() and lambda syntax do not exist in Apex
Map<Id, WorkOrder> woMap = new Map<Id, WorkOrder>([
    SELECT Id, FM__c, Lot_Address__c, Need_Further_Info_Notes__c, NFI_Count__c
    FROM WorkOrder WHERE Id IN :wos.stream().map(w -> w.Id).toList()
]);
// Note: above SOQL style won't work — use explicit loop
```

A valid workaround follows immediately (the `woFullMap` at lines 378–383) but `woMap` is declared and never used. This is dead code with a syntax error.

**Risk:** If this code was ever deployed without a compile error being caught, it indicates the package was not validated before upload. Additionally, `woMap` is a variable shadow that wastes memory per transaction.

**Fix:** Delete lines 373–377 entirely. The working `woFullMap` block below is sufficient.

```apex
// Remove the broken block. Keep only:
Set<Id> woIds = new Set<Id>();
for (WorkOrder wo : wos) woIds.add(wo.Id);
Map<Id, WorkOrder> woFullMap = new Map<Id, WorkOrder>([
    SELECT Id, FM__c, Lot_Address__c, Need_Further_Info_Notes__c, NFI_Count__c
    FROM WorkOrder WHERE Id IN :woIds
]);
```

---

### FINDING 5 — `clearAlreadyRun` Defeats the Recursion Guard  
**Severity: MEDIUM**

`LOVING_TriggerGuard.clearAlreadyRun('WorkOrder')` is called in 4 places to re-enable trigger execution before a DML operation:

- `autoCloseWorkOrders` — before `update toClose` (line 486)
- `createSubTickets` — before `insert tickets` (line 537)
- `LOVING_MeasuringCupService.recalculateGP` — before `update toUpdate` (line 106)
- `LOVING_AquaTicketService.createAquaInstallTickets` — before `insert aquaTickets` (line 70)

The guard exists to prevent infinite recursion. Manually clearing it before each DML means any of these code paths can re-enter the trigger. The risk is specifically when one of these updates itself changes a status that routes back into the same handler path.

For example: `autoCloseWorkOrders` clears the guard and does `update [Status='Closed']`. The trigger fires again. If the closed WO somehow routes into `autoCloseWorkOrders` again (e.g., via a Flow that sets Payment_Received__c), the guard is already clear and the loop continues.

**Fix:** Use a static counter or separate guard flags for system-generated updates rather than clearing the primary guard:

```apex
// In TriggerGuard, add:
private static Set<String> systemContextObjects = new Set<String>();

public static void setSystemContext(String objectName) {
    systemContextObjects.add(objectName);
}
public static Boolean isSystemContext(String objectName) {
    return systemContextObjects.contains(objectName);
}

// In trigger:
if (LOVING_TriggerGuard.hasAlreadyRun('WorkOrder')
    && !LOVING_TriggerGuard.isSystemContext('WorkOrder')) {
    return;
}
```

---

### FINDING 6 — Invoice Task Has No Owner  
**Severity: LOW**

`handleStatusToApproved` creates an Invoicing Task with no `OwnerId` (lines 349–361). The task is assigned to whoever ran the trigger, not to the Finance team. A comment notes this is a known gap:

> "For now: assign to WO FM's manager — replace with Finance queue in production"

The actual code does not assign to the FM's manager either — `OwnerId` is simply not set. In production, these tasks will pile up in the running user's queue or be lost.

**Fix:** Create a public Group or Queue named "Finance – Invoicing" and assign the Task OwnerId to that Group's Id (query `Group WHERE Type='Queue' AND DeveloperName='Finance_Invoicing'`).

---

### FINDING 7 — GP Hard Floor Override is Documentation-Only  
**Severity: LOW**

The `GP_Hard_Floor_Invoice_Block` validation rule tells users to "contact your COO and document the approval in the Closeout Notes field before proceeding." But there is no system enforcement of this process — a user could write anything in `Closeout_Notes__c` and then re-enter the invoice number.

**Risk:** GP floor bypasses are self-documented by the person requesting the bypass. There is no audit trail tied to a specific approver.

**Recommended improvement:** Add a lookup field `GP_Override_Approved_By__c` (User) and add it to the validation rule formula:

```
AND(
    NOT(ISBLANK(Invoice_Number__c)),
    ISCHANGED(Invoice_Number__c),
    NOT(ISBLANK(Gross_Margin_Pct__c)),
    Gross_Margin_Pct__c < 22,
    ISBLANK(GP_Override_Approved_By__c)  // must be populated by COO
)
```

This ensures bypasses require a named approver on the record (auditable).

---

### FINDING 8 — `createFirstCheckTicket` and `createPickupTicket` Are Not Bulkified  
**Severity: LOW**

Both methods in `LOVING_AquaTicketService` accept a single record and contain SOQL inside the method body. If either is called from a Flow or Process Builder with multiple records in a single transaction, each call will consume a separate SOQL query, risking the 100 SOQL per transaction governor limit.

`createFirstCheckTicket` — 1 SOQL query  
`createPickupTicket` — 3 SOQL queries + 1 DML for cancelling future checks

**Fix:** These are currently only called one record at a time. Add a `@SuppressWarnings('PMD.ApexSOQLInjection')` note and document the single-record contract, or refactor to accept `List<WorkOrder>` and bulk-query outside the loop.

---

## SUMMARY TABLE

| # | Finding | Severity | Area |
|---|---|---|---|
| 1 | MFA not enforced for Username/Password | HIGH | Org Config |
| 2 | Excessive marketing connectors enabled | LOW | Org Config |
| 3 | All service classes use `without sharing` | HIGH | Apex |
| 4 | Dead/broken SOQL in `handleStatusToNFI` | MEDIUM | Apex |
| 5 | `clearAlreadyRun` defeats recursion guard | MEDIUM | Apex |
| 6 | Invoice task has no OwnerId | LOW | Apex |
| 7 | GP floor override is documentation-only | LOW | Config |
| 8 | Aqua ticket methods not bulkified | LOW | Apex |

---

## RECOMMENDED ACTION ORDER

1. **Before go-live:** Enforce MFA (Finding 1) — zero code change, one config step
2. **Before go-live:** Fix `without sharing` → `inherited sharing` on trigger handler (Finding 3)
3. **Before go-live:** Delete dead SOQL block in `handleStatusToNFI` (Finding 4)
4. **Post go-live P1:** Replace `clearAlreadyRun` pattern with system-context guard (Finding 5)
5. **Post go-live P1:** Assign Invoice tasks to Finance Queue (Finding 6)
6. **Phase 2:** Add GP override approver field (Finding 7)
7. **Phase 2:** Review and disable unused Connected Apps (Finding 2)
8. **Phase 2:** Bulkify Aqua ticket methods (Finding 8)
