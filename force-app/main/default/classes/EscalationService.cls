/**
 * EscalationService
 * Central hub for all system escalations, alerts, and notifications.
 *
 * Covers all escalation rules from the process guide:
 *   Stage 4  — No takeoff started after bucket window → FM (then CSM) — 48 hrs
 *   Stage 5  — Takeoff not submitted within 48 hrs of start → FM → CSM
 *   Stage 7  — Site readiness not completed → FM → Scheduling Manager
 *   Stage 8  — Site readiness not marked complete by T-48 hrs
 *   Stage 10 — No health check response by 2:15 PM → CSM
 *   Stage 12 — NFI count > 2 → Customer Success Manager → COO (Meg)
 *   Stage 15 — QI not completed within builder deadline → FM → CSM → COO
 *   Stage 16 — Invoice unpaid > 30 days → Finance → COO
 *   Aqua     — Tampering, low scores, inventory imbalance → Scott / Erica / FM
 */
public with sharing class EscalationService {

    // ─────────────────────────────────────────────
    // TEST INJECTION
    // WorkOrder INSERT is blocked in this org's test context.
    // Methods that do single-record WorkOrder SOQL use this injected WO
    // when running in test context so SOQL doesn't throw QueryException.
    // Reset to null after each test.
    // ─────────────────────────────────────────────
    @TestVisible static WorkOrder injectedWorkOrderForSOQL = null;

    // ─────────────────────────────────────────────
    // LEAD ESCALATIONS
    // ─────────────────────────────────────────────
    public static void notifyCOODeadLeads(List<Id> leadIds) {
        sendAlert(getCOOId(), 'Lead Marked Dead',
            leadIds.size() + ' lead(s) marked Dead. Review required.',
            leadIds[0]);
    }

    // ─────────────────────────────────────────────
    // TAKEOFF ESCALATIONS
    // ─────────────────────────────────────────────
    public static void escalateTakeoffOverdue(List<WorkOrder> staleWOs) {
        for (WorkOrder wo : staleWOs) {
            sendAlert(wo.Field_Manager__c, 'TAKEOFF OVERDUE — ' + wo.WorkOrderNumber,
                'Takeoff has not been started on this Work Order. It is in the 30 Days bucket. Complete takeoff immediately.',
                wo.Id);
        }
        // Escalate to Ops Manager after another 24 hours (handled by next scheduler run)
    }

    public static void escalateTakeoffSLABreach(Id workOrderId) {
        WorkOrder wo = injectedWorkOrderForSOQL != null ? injectedWorkOrderForSOQL :
            [SELECT Id, WorkOrderNumber, Field_Manager__c FROM WorkOrder WHERE Id = :workOrderId];
        sendAlert(wo.Field_Manager__c, 'TAKEOFF SLA BREACH — ' + wo.WorkOrderNumber,
            'Takeoff has been In Progress for more than 48 hours without submission. Submit immediately or contact your Customer Success Manager.',
            workOrderId);
        sendAlert(getCSMId(), 'TAKEOFF SLA BREACH — ' + wo.WorkOrderNumber,
            'FM has not submitted takeoff within 48 hours. Work Order: ' + wo.WorkOrderNumber,
            workOrderId);
    }

    public static void escalateTakeoffTooCOO(Id workOrderId, Integer nfiCount) {
        sendAlert(getCOOId(), 'TAKEOFF RETURNED ' + nfiCount + ' TIMES — ESCALATION',
            'Takeoff has been returned for correction ' + nfiCount + ' times. COO review required before further action.',
            workOrderId);
    }

    public static void notifyFMTakeoffReturned(Id workOrderId, String reason) {
        WorkOrder wo = injectedWorkOrderForSOQL != null ? injectedWorkOrderForSOQL :
            [SELECT Id, Field_Manager__c FROM WorkOrder WHERE Id = :workOrderId];
        sendAlert(wo.Field_Manager__c, 'Takeoff Returned for Correction',
            'Your takeoff submission has been returned. Reason: ' + reason + '. Please correct and resubmit.',
            workOrderId);
    }

    public static void notifySchedulingManagerReadyToSchedule(Id workOrderId) {
        sendAlert(getSchedulingMgrId(), 'Ready to Schedule',
            'Work Order is now approved and ready to schedule.',
            workOrderId);
    }

    // ─────────────────────────────────────────────
    // SCHEDULING ESCALATIONS
    // ─────────────────────────────────────────────
    public static void notifySchedulingManagerSiteNotReady(Id workOrderId, String reason) {
        sendAlert(getSchedulingMgrId(), 'SITE NOT READY — Schedule Pulled',
            'FM marked site as Not Ready. Reason: ' + reason + '. Work Order returned to scheduling queue.',
            workOrderId);
    }

    // ─────────────────────────────────────────────
    // HEALTH CHECK ESCALATIONS (Stage 10)
    // ─────────────────────────────────────────────
    public static void alertRedHealthCheck(Id workOrderId, String redFlagNotes) {
        sendAlert(getSchedulingMgrId(), 'RED HEALTH CHECK — Action Required',
            'FM marked Red at 2 PM. ' + redFlagNotes + '. Decision required: FJ / EXT / SCHED.',
            workOrderId);
        sendAlert(getOpsMgrId(), 'RED HEALTH CHECK — ' + workOrderId,
            'Active Work Order flagged Red at 2 PM health check. Notes: ' + redFlagNotes,
            workOrderId);
    }

    public static void escalateHealthCheckNoResponse(Id workOrderId, Id fmId) {
        sendAlert(getCSMId(), 'HEALTH CHECK — NO RESPONSE',
            'FM has not responded to the 2 PM health check within 15 minutes. Immediate follow-up required.',
            workOrderId);
    }

    public static void notifyFMRedDecision(Id workOrderId, String decision, String notes) {
        WorkOrder wo = injectedWorkOrderForSOQL != null ? injectedWorkOrderForSOQL :
            [SELECT Id, Field_Manager__c FROM WorkOrder WHERE Id = :workOrderId];
        String decisionLabel = decision == 'FJ' ? 'Finish Job Created' :
                               decision == 'EXT' ? 'Crew Extended' : 'Rescheduled';
        sendAlert(wo.Field_Manager__c, 'Health Check Decision: ' + decisionLabel,
            'Scheduling decision for your Red health check: ' + decisionLabel + '. Notes: ' + notes,
            workOrderId);
    }

    // ─────────────────────────────────────────────
    // NFI ESCALATIONS (Stage 12)
    // ─────────────────────────────────────────────
    public static void escalateNFIToCOO(Id workOrderId, Integer nfiCount) {
        Id cooId = getCOOId();
        sendAlert(cooId, 'NFI ESCALATION — ' + nfiCount + ' Returns',
            'This Work Order has been returned to FM for Need Further Info ' + nfiCount + ' times. COO review required before it can advance.',
            workOrderId);
        LovingNotificationService.notifyNFIEscalated(workOrderId, cooId, nfiCount);
    }

    public static void notifyFMNFI(Id workOrderId, String reason) {
        WorkOrder wo = injectedWorkOrderForSOQL != null ? injectedWorkOrderForSOQL :
            [SELECT Id, Field_Manager__c FROM WorkOrder WHERE Id = :workOrderId];
        sendAlert(wo.Field_Manager__c, 'Work Order Returned — Need Further Info',
            'Your closeout submission has been returned. Reason: ' + reason + '. Resolve and resubmit.',
            workOrderId);
        LovingNotificationService.notifyNFIReturned(workOrderId, wo.Field_Manager__c, reason);
    }

    // ─────────────────────────────────────────────
    // CSM CLOSEOUT APPROVAL (Stage 11 → 13)
    // Foreman submitted Job Complete — CSM owns the approval.
    // ─────────────────────────────────────────────
    public static void notifyCSMPendingApproval(Id workOrderId) {
        sendAlert(getCSMId(), 'Job Complete Submitted — CSM Approval Required',
            'Foreman has submitted Job Complete. CSM must approve or flag NFI within 24 hours.',
            workOrderId);
    }

    // ─────────────────────────────────────────────
    // QI ESCALATIONS (Stage 15)
    // ─────────────────────────────────────────────
    public static void notifyCSMAcceptableQI(Id workOrderId, Id csmId, Decimal score) {
        sendAlert(csmId, 'QI Score: Acceptable — Review Required',
            'QI average score is ' + ((Decimal)score).setScale(1) + ' (Acceptable range: 5–7.9). No rework required unless specific items scored below 4. Please review.',
            workOrderId);
    }

    public static void alertRedQI(Id workOrderId, Id csmId, Id fmId, Decimal score) {
        String msg = 'QI average score is ' + ((Decimal)score).setScale(1) + ' (below 5). Work Order is HELD. Rework decision required: Approve with note / Create Finish Job / Escalate to Jim Howie.';
        sendAlert(csmId, 'RED QI SCORE — WO HELD', msg, workOrderId);
        sendAlert(getCOOId(), 'RED QI SCORE — WO HELD', msg, workOrderId);
        LovingNotificationService.notifyQIRedScore(workOrderId, fmId, csmId, score);
    }

    public static void escalateQISLABreach(Id workOrderId, Id fmId) {
        sendAlert(fmId, 'QI INSPECTION OVERDUE',
            'QI Inspection has not been completed within the required deadline. Complete immediately.',
            workOrderId);
        sendAlert(getCSMId(), 'QI INSPECTION OVERDUE',
            'QI Inspection SLA breach. Work Order has been Approved and QI deadline has passed without a completed inspection.',
            workOrderId);
        sendAlert(getCOOId(), 'QI INSPECTION OVERDUE — ESCALATED',
            'QI Inspection SLA exceeded. COO awareness required.',
            workOrderId);
        LovingNotificationService.notifyQISLABreach(workOrderId, fmId);
    }

    public static void alertSiteReadinessOverdue(Id workOrderId, Id fmId) {
        sendAlert(fmId, 'SITE READINESS CHECK OVERDUE',
            'Site readiness check deadline has passed. Confirm site ready, flag not ready, or waive before crew arrives.',
            workOrderId);
        LovingNotificationService.notifySiteReadinessOverdue(workOrderId, fmId);
    }

    // ─────────────────────────────────────────────
    // INVOICE ESCALATIONS (Stage 16)
    // ─────────────────────────────────────────────
    public static void escalateUnpaidInvoice(Id invoiceId, Id workOrderId) {
        sendAlert(getFinanceId(), 'UNPAID INVOICE — 30 DAYS',
            'Invoice has been outstanding for 30+ days with no payment received. Follow up with builder immediately.',
            invoiceId);
        sendAlert(getCOOId(), 'UNPAID INVOICE — ESCALATED',
            'Invoice unpaid > 30 days. COO attention required.',
            invoiceId);
    }

    // ─────────────────────────────────────────────
    // AUTO-CLOSE ESCALATIONS (Stage 18)
    // ─────────────────────────────────────────────
    public static void alertFinanceQICompleteNotPaid(Id workOrderId) {
        sendAlert(getFinanceId(), 'QI Complete — Invoice Not Yet Paid',
            'QI Inspection is complete. Work Order is pending payment to auto-close.',
            workOrderId);
    }

    public static void alertFMQINotCompleteAfterPayment(Id workOrderId) {
        WorkOrder wo = injectedWorkOrderForSOQL != null ? injectedWorkOrderForSOQL :
            [SELECT Id, Field_Manager__c FROM WorkOrder WHERE Id = :workOrderId];
        sendAlert(wo.Field_Manager__c, 'Invoice Paid — QI Inspection Required to Close',
            'Payment received. This Work Order cannot auto-close until QI Inspection is marked complete.',
            workOrderId);
    }

    // ─────────────────────────────────────────────
    // AQUA ESCALATIONS
    // ─────────────────────────────────────────────
    public static void alertAquaTamperingDetected(Id workOrderId, Id checkTicketId) {
        sendAlert(getScottId(), 'AQUA — TAMPERING DETECTED',
            'Aqua system tampering detected on Work Order. Immediate review required.',
            checkTicketId);
    }

    public static void alertTurfConditionLow(Id workOrderId, Decimal score) {
        sendAlert(getEricaId(), 'AQUA — LOW TURF CONDITION: ' + score,
            'Turf condition score of ' + score + ' (below 5). Photo required. Immediate review.',
            workOrderId);
    }

    public static void alertLandscapeConditionLow(Id workOrderId, Decimal score) {
        // Work Order IS the lot/job — look up FM directly
        List<WorkOrder> wos = [SELECT Id, Field_Manager__c FROM WorkOrder WHERE Id = :workOrderId LIMIT 1];
        Id fmId = (!wos.isEmpty() && wos[0].Field_Manager__c != null) ? wos[0].Field_Manager__c : UserInfo.getUserId();
        sendAlert(fmId, 'AQUA — LOW LANDSCAPE CONDITION: ' + score,
            'Landscape condition score of ' + score + ' (below 5). Photo required. Immediate review.',
            workOrderId);
    }

    public static void alertAquaInventoryMismatch(Id workOrderId,
        Decimal expCtrl, Decimal actCtrl,
        Decimal expHeads, Decimal actHeads) {
        sendAlert(getScottId(), 'AQUA INVENTORY MISMATCH',
            'Inventory mismatch on Work Order ' + workOrderId + '. '
            + 'Controllers: expected ' + expCtrl + ', actual ' + actCtrl + '. '
            + 'Heads: expected ' + expHeads + ', actual ' + actHeads + '.',
            workOrderId);
    }

    public static void alertAquaGlobalInventoryImbalance(String itemType, Decimal master, Decimal current) {
        sendAlert(getScottId(), 'AQUA GLOBAL INVENTORY IMBALANCE: ' + itemType,
            'Global inventory imbalance detected for ' + itemType + '. '
            + 'Master total: ' + master + '. Current tracked total: ' + current + '. '
            + 'Sum of Shop + Van + On-Site does not balance. Immediate reconciliation required.',
            null);
    }

    // ─────────────────────────────────────────────
    // CORE NOTIFICATION DISPATCH
    // Uses Custom Notification Type — configurable in Setup
    // ─────────────────────────────────────────────
    public static void sendAlert(Id recipientId, String title, String body, Id recordId) {
        if (recipientId == null) return;
        try {
            CustomNotificationType notifType = [
                SELECT Id FROM CustomNotificationType
                WHERE DeveloperName = 'LOVING_System_Alert' LIMIT 1
            ];

            Messaging.CustomNotification notification = new Messaging.CustomNotification();
            notification.setTitle(title);
            notification.setBody(body);
            notification.setNotificationTypeId(notifType.Id);
            if (recordId != null) notification.setTargetId(recordId);
            notification.send(new Set<String>{ recipientId });
        } catch (Exception e) {
            // Fall back to Chatter post if push notification fails
            postChatterAlert(recipientId, title + ': ' + body, recordId);
        }
    }

    private static void postChatterAlert(Id recipientId, String message, Id recordId) {
        FeedItem post = new FeedItem(
            ParentId = recordId != null ? recordId : UserInfo.getUserId(),
            Body     = '@' + [SELECT Username FROM User WHERE Id = :recipientId LIMIT 1].Username + ' — ' + message
        );
        insert post;
    }

    // ─────────────────────────────────────────────
    // ROLE LOOKUPS — cached per transaction
    // ─────────────────────────────────────────────
    private static Id cooId;
    private static Id csmId;
    private static Id opsMgrId;
    private static Id schedulingMgrId;
    private static Id financeId;
    private static Id scottId;
    private static Id ericaId;

    public static Id getCOOId() {
        if (cooId == null) cooId = getUserByName('Meg Logan');
        return cooId;
    }
    /** Customer Success Manager — reviews closeout, approves/NFIs Work Orders */
    public static Id getCSMId() {
        if (csmId == null) csmId = getUserByRole('Customer Success Manager');
        return csmId;
    }
    /** Kept for backward compatibility — routes to CSM role */
    public static Id getOpsMgrId() {
        if (opsMgrId == null) opsMgrId = getUserByRole('Ops Manager');
        return opsMgrId;
    }
    public static Id getSchedulingMgrId() {
        if (schedulingMgrId == null) schedulingMgrId = getUserByRole('Scheduling Manager');
        return schedulingMgrId;
    }
    public static Id getFinanceId() {
        if (financeId == null) financeId = getUserByRole('Finance');
        return financeId;
    }
    public static Id getScottId() {
        if (scottId == null) scottId = getUserByName('Scott');
        return scottId;
    }
    public static Id getEricaId() {
        if (ericaId == null) ericaId = getUserByName('Erica');
        return ericaId;
    }

    private static Id getUserByName(String name) {
        List<User> users = [SELECT Id FROM User WHERE Name = :name AND IsActive = true LIMIT 1];
        return users.isEmpty() ? UserInfo.getUserId() : users[0].Id;
    }
    private static Id getUserByRole(String roleName) {
        List<User> users = [
            SELECT Id FROM User
            WHERE UserRole.Name = :roleName AND IsActive = true LIMIT 1
        ];
        return users.isEmpty() ? UserInfo.getUserId() : users[0].Id;
    }
}