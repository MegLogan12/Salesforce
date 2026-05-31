/**
 * ForemanMobileNotificationService
 *
 * Invocable Apex service for Foreman Mobile FSL Screen Flows.
 * Called from LOVING_Foreman_FlagIssue flow when a flag is submitted in the field.
 *
 * Missing Material flag recipients (per spec):
 *   - Field Manager on the Work Order (WorkOrder.Field_Manager__c)
 *   - Jim Howie (queried by Name from User)
 *   - Inventory Specialist (queried by LOVING_Inventory_Specialist permission set)
 *   - T.R. Haynes (queried by Name from User)
 *
 * All other flag types: notify FM on the Work Order only.
 *
 * Does NOT notify Fleet or Ops on any flag type (per spec).
 * Does NOT show dollar values or contact info to foreman in notifications.
 *
 * Notification type used: LOVING_Missing_Material_Alert for missing material.
 *                         LOVING_NFI_Alert for all other flag types.
 *
 * Error handling: writes to Error_Log__c on failure. Does not throw exceptions
 * to the calling flow — the flow shows success even if notification fails,
 * because the Schedule_Issue__c record was already created.
 */
public with sharing class ForemanMobileNotificationService {

    // ─────────────────────────────────────────────
    //  INVOCABLE INPUT
    // ─────────────────────────────────────────────

    public class FlagInput {
        @InvocableVariable(label='Work Order Id' required=true)
        public Id workOrderId;

        @InvocableVariable(label='Flag Type' required=true)
        public String flagType;

        @InvocableVariable(label='Flag Notes' required=false)
        public String flagNotes;
    }

    // ─────────────────────────────────────────────
    //  INVOCABLE METHOD
    // ─────────────────────────────────────────────

    @InvocableMethod(
        label       = 'Send Foreman Field Flag Notification'
        description = 'Called from LOVING_Foreman_FlagIssue flow. Routes notification based on flag type. Missing Material notifies FM + Jim Howie + Inventory Specialist + T.R. Haynes. All other flags notify FM only. Never notifies Fleet or Ops.'
        category    = 'LOVING Foreman Mobile'
    )
    public static void sendFlagNotification(List<FlagInput> inputs) {
        if (inputs == null || inputs.isEmpty()) return;
        FlagInput input = inputs[0];
        try {
            sendFlagNotificationInternal(input.workOrderId, input.flagType, input.flagNotes);
        } catch (Exception ex) {
            logError('ForemanMobileNotificationService.sendFlagNotification',
                     ex.getMessage(), input.workOrderId);
        }
    }

    // ─────────────────────────────────────────────
    //  INTERNAL LOGIC
    // ─────────────────────────────────────────────

    @TestVisible
    static void sendFlagNotificationInternal(Id workOrderId, String flagType, String flagNotes) {

        // 1. Get Work Order + FM
        WorkOrder wo = [
            SELECT Id, Subject, Lot_Number__c, Work_Order_Type__c,
                   Field_Manager__c
            FROM   WorkOrder
            WHERE  Id = :workOrderId
            LIMIT  1
        ];

        Set<String> recipientIds = new Set<String>();

        // 2. Always include FM
        if (wo.Field_Manager__c != null) {
            recipientIds.add(wo.Field_Manager__c);
        }

        // 3. Missing Material — add Jim Howie, Inventory Specialist, T.R. Haynes
        if (flagType == 'Missing Material') {
            addNamedUser('Jim Howie', recipientIds);
            addNamedUser('T.R. Haynes', recipientIds);
            addInventorySpecialists(recipientIds);
        }

        if (recipientIds.isEmpty()) {
            logError('ForemanMobileNotificationService',
                     'No recipients resolved for flag type: ' + flagType, workOrderId);
            return;
        }

        // 4. Build notification
        String notifTypeName = (flagType == 'Missing Material')
            ? 'LOVING_Missing_Material_Alert'
            : 'LOVING_NFI_Alert';

        CustomNotificationType notifType = [
            SELECT Id
            FROM   CustomNotificationType
            WHERE  DeveloperName = :notifTypeName
            LIMIT  1
        ];

        String title = buildTitle(flagType, wo);
        String body  = buildBody(flagType, flagNotes, wo);

        Messaging.CustomNotification notif = new Messaging.CustomNotification();
        notif.setNotificationTypeId(notifType.Id);
        notif.setTitle(title);
        notif.setBody(body);
        notif.setTargetId(workOrderId);
        notif.send(recipientIds);
    }

    // ─────────────────────────────────────────────
    //  HELPER: Add named user by full name
    // ─────────────────────────────────────────────

    private static void addNamedUser(String fullName, Set<String> recipientIds) {
        List<User> users = [
            SELECT Id
            FROM   User
            WHERE  Name = :fullName
            AND    IsActive = true
            LIMIT  1
        ];
        if (!users.isEmpty()) {
            recipientIds.add(users[0].Id);
        }
    }

    // ─────────────────────────────────────────────
    //  HELPER: Add all active Inventory Specialists
    // ─────────────────────────────────────────────

    private static void addInventorySpecialists(Set<String> recipientIds) {
        for (PermissionSetAssignment psa : [
            SELECT AssigneeId
            FROM   PermissionSetAssignment
            WHERE  PermissionSet.Name = 'LOVING_Inventory_Specialist'
            AND    Assignee.IsActive   = true
        ]) {
            recipientIds.add(psa.AssigneeId);
        }
    }

    // ─────────────────────────────────────────────
    //  HELPER: Build notification title
    // ─────────────────────────────────────────────

    private static String buildTitle(String flagType, WorkOrder wo) {
        if (flagType == 'Missing Material') {
            return 'MISSING MATERIAL — ' + (wo.Lot_Number__c != null ? 'Lot ' + wo.Lot_Number__c : wo.Subject);
        }
        return flagType.toUpperCase() + ' FLAG — ' + (wo.Lot_Number__c != null ? 'Lot ' + wo.Lot_Number__c : wo.Subject);
    }

    // ─────────────────────────────────────────────
    //  HELPER: Build notification body
    // ─────────────────────────────────────────────

    private static String buildBody(String flagType, String flagNotes, WorkOrder wo) {
        String body = (wo.Work_Order_Type__c != null ? wo.Work_Order_Type__c : 'Work Order');
        if (wo.Lot_Number__c != null) {
            body += ' · Lot ' + wo.Lot_Number__c;
        }
        if (String.isNotBlank(flagNotes)) {
            body += ' · ' + flagNotes.abbreviate(200);
        }
        return body;
    }

    // ─────────────────────────────────────────────
    //  HELPER: Write to Error_Log__c
    // ─────────────────────────────────────────────

    private static void logError(String source, String message, Id relatedId) {
        try {
            insert new Error_Log__c(
                Class_Name__c = source,
                Message__c    = message,
                Record_Id__c  = String.valueOf(relatedId),
                Logged_At__c  = Datetime.now()
            );
        } catch (Exception ignored) {
            // Error logging must never throw
        }
    }
}