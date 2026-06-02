/**
 * LovingNotificationService
 * Sends in-app (bell icon) and mobile push notifications via Salesforce
 * CustomNotificationType. Replaces email-only escalation paths in
 * EscalationService for real-time console alerts.
 *
 * Each method maps to a CustomNotificationType defined in:
 *   customNotifications/LOVING_*.customNotification-meta.xml
 *
 * Notifications appear in the SF bell icon (desktop) and SF mobile push.
 * They deep-link to the relevant WO or Takeoff record.
 */
public with sharing class LovingNotificationService {

    // ─────────────────────────────────────────────
    // NOTIFICATION TYPE API NAMES
    // ─────────────────────────────────────────────
    private static final String TYPE_QI            = 'LOVING_QI_Alert';
    private static final String TYPE_SITE_READINESS = 'LOVING_Site_Readiness_Alert';
    private static final String TYPE_SCHEDULE       = 'LOVING_Schedule_Alert';
    private static final String TYPE_NFI            = 'LOVING_NFI_Alert';

    // ─────────────────────────────────────────────
    // QI ALERTS
    // ─────────────────────────────────────────────
    public static void notifyQISLABreach(Id workOrderId, Id fmUserId) {
        send(
            TYPE_QI,
            'QI Inspection Overdue',
            'QI inspection past due date on ' + getWONumber(workOrderId) + '. Complete or escalate immediately.',
            workOrderId,
            new Set<String>{ fmUserId }
        );
    }

    public static void notifyQIRedScore(Id workOrderId, Id fmUserId, Id csmUserId, Decimal score) {
        String msg = 'QI score ' + score.format() + ' on ' + getWONumber(workOrderId) + ' — WO placed On Hold. Rework required.';
        Set<String> recipients = new Set<String>{ fmUserId };
        if (csmUserId != null) recipients.add(csmUserId);
        send(TYPE_QI, 'QI Red Score — Rework Required', msg, workOrderId, recipients);
    }

    // ─────────────────────────────────────────────
    // SITE READINESS ALERTS
    // ─────────────────────────────────────────────
    public static void notifySiteReadinessOverdue(Id workOrderId, Id fmUserId) {
        send(
            TYPE_SITE_READINESS,
            'Site Readiness Check Overdue',
            'Site readiness deadline passed for ' + getWONumber(workOrderId) + '. Confirm ready, flag not ready, or waive.',
            workOrderId,
            new Set<String>{ fmUserId }
        );
    }

    public static void notifySiteNotReady(Id workOrderId, Id schedulingUserId, String notes) {
        send(
            TYPE_SITE_READINESS,
            'Site Not Ready — Install Blocked',
            getWONumber(workOrderId) + ' flagged Not Ready. ' + (notes != null ? notes : ''),
            workOrderId,
            new Set<String>{ schedulingUserId }
        );
    }

    // ─────────────────────────────────────────────
    // NFI ALERTS
    // ─────────────────────────────────────────────
    public static void notifyNFIReturned(Id workOrderId, Id fmUserId, String reason) {
        send(
            TYPE_NFI,
            'Work Order Returned — Need Further Info',
            getWONumber(workOrderId) + ' returned by CS. Reason: ' + (reason != null ? reason : 'See record.'),
            workOrderId,
            new Set<String>{ fmUserId }
        );
    }

    public static void notifyNFIEscalated(Id workOrderId, Id cooUserId, Integer nfiCount) {
        send(
            TYPE_NFI,
            'NFI Escalation — COO Review Required',
            getWONumber(workOrderId) + ' has ' + nfiCount + ' NFI returns. COO review required.',
            workOrderId,
            new Set<String>{ cooUserId }
        );
    }

    // ─────────────────────────────────────────────
    // SCHEDULING ALERTS
    // ─────────────────────────────────────────────
    public static void notifySameDayRepair(Id workOrderId, Set<String> schedulingUserIds) {
        send(
            TYPE_SCHEDULE,
            'Same-Day Repair Created',
            'New same-day repair on ' + getWONumber(workOrderId) + '. Assign tech immediately.',
            workOrderId,
            schedulingUserIds
        );
    }

    public static void notifyGPSOffline(Id workOrderId, String techName) {
        Set<String> admins = getSchedulingAdminIds();
        send(
            TYPE_SCHEDULE,
            'GPS Signal Lost — ' + techName,
            'WEX GPS offline for ' + techName + '. Last known position unavailable. Check manually.',
            workOrderId,
            admins
        );
    }

    // ─────────────────────────────────────────────
    // CORE SEND METHOD
    // ─────────────────────────────────────────────

    /**
     * Test injection: set to a valid-format CustomNotificationType Id (e.g. 0ML...)
     * to allow send() to proceed past the null-type guard.
     * The actual notif.send() call will throw and the catch block will fire,
     * covering the error-path and ErrorLogService lines in test context.
     * Reset to null after each test.
     */
    @TestVisible static Id mockNotifTypeIdForTest = null;

    private static void send(
        String typeName,
        String title,
        String body,
        Id targetRecordId,
        Set<String> recipientUserIds
    ) {
        if (recipientUserIds == null || recipientUserIds.isEmpty()) return;

        // Remove nulls
        Set<String> cleanRecipients = new Set<String>();
        for (String r : recipientUserIds) {
            if (r != null) cleanRecipients.add(r);
        }
        if (cleanRecipients.isEmpty()) return;

        CustomNotificationType notifType = getNotificationType(typeName);
        Id notifTypeId = notifType != null ? notifType.Id : mockNotifTypeIdForTest;
        if (notifTypeId == null) return;

        Messaging.CustomNotification notif = new Messaging.CustomNotification();
        notif.setTitle(title);
        notif.setBody(body);
        notif.setNotificationTypeId(notifTypeId);
        if (targetRecordId != null) notif.setTargetId(targetRecordId);

        try {
            notif.send(cleanRecipients);
        } catch (Exception e) {
            ErrorLogService.log('LovingNotificationService', 'send', null, e.getMessage() + ' | type: ' + typeName);
        }
    }

    // ─────────────────────────────────────────────
    // HELPERS
    // ─────────────────────────────────────────────
    private static Map<String, CustomNotificationType> typeCache = new Map<String, CustomNotificationType>();

    private static CustomNotificationType getNotificationType(String apiName) {
        if (typeCache.containsKey(apiName)) return typeCache.get(apiName);
        List<CustomNotificationType> types = [
            SELECT Id, CustomNotifTypeName FROM CustomNotificationType
            WHERE CustomNotifTypeName = :apiName LIMIT 1
        ];
        CustomNotificationType t = types.isEmpty() ? null : types[0];
        typeCache.put(apiName, t);
        return t;
    }

    private static String getWONumber(Id woId) {
        if (woId == null) return 'WO';
        List<WorkOrder> wos = [SELECT WorkOrderNumber FROM WorkOrder WHERE Id = :woId LIMIT 1];
        return wos.isEmpty() ? 'WO' : wos[0].WorkOrderNumber;
    }

    private static Set<String> getSchedulingAdminIds() {
        Set<String> ids = new Set<String>();
        for (User u : [
            SELECT Id FROM User
            WHERE Profile.Name = 'Scheduling Admin'
            AND IsActive = true
            LIMIT 10
        ]) { ids.add(u.Id); }
        return ids;
    }
}