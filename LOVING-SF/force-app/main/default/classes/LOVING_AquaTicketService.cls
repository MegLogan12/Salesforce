/**
 * LOVING_AquaTicketService
 *
 * Creates and manages Aqua Install, Check, and Pickup tickets as WorkOrder
 * sub-records. Called from LOVING_WorkOrderTriggerHandler and the
 * LOVING_PI_Aqua_Trigger Flow.
 *
 * Rules:
 *   - Aqua Install Ticket: auto-created when a Production Install WO is Scheduled
 *     and the community has Aqua_Community__c = true.
 *   - Aqua Check Ticket: auto-created next community service day after Install closes.
 *   - Aqua Pickup Ticket: created when lot is marked Closed.
 *   - All Aqua tickets are WorkOrder records with Work_Order_Type__c set accordingly.
 */
public without sharing class LOVING_AquaTicketService {

    // ── Constants ────────────────────────────────────────────────────────────
    private static final String TYPE_INSTALL = 'Aqua Install';
    private static final String TYPE_CHECK   = 'Aqua Check';
    private static final String TYPE_PICKUP  = 'Aqua Pickup';

    // ── Create Aqua Install Tickets ──────────────────────────────────────────
    /**
     * Called when a Production Install WO is Scheduled and Aqua_Community__c = true.
     * Creates one Aqua Install Ticket per WO, same date, same crew.
     */
    public static void createAquaInstallTickets(List<WorkOrder> productionWOs) {
        if (productionWOs.isEmpty()) return;

        Set<Id> communityIds = new Set<Id>();
        for (WorkOrder wo : productionWOs) {
            if (wo.Community__c != null) communityIds.add(wo.Community__c);
        }

        // Load community Aqua config
        Map<Id, Account> communities = new Map<Id, Account>([
            SELECT Id, Aqua_Tech__c, Aqua_Customer__c
            FROM Account
            WHERE Id IN :communityIds AND Aqua_Customer__c = true
        ]);

        List<WorkOrder> aquaTickets = new List<WorkOrder>();

        for (WorkOrder wo : productionWOs) {
            Account comm = communities.get(wo.Community__c);
            if (comm == null) continue;

            WorkOrder aq             = new WorkOrder();
            aq.Work_Order_Type__c    = TYPE_INSTALL;
            aq.Status                = 'New';
            aq.AccountId             = wo.AccountId;      // Lot
            aq.Community__c          = wo.Community__c;
            aq.Builder_Regional__c   = wo.Builder_Regional__c;
            aq.Lot__c                = wo.Lot__c;
            aq.Lot_Address__c        = wo.Lot_Address__c;
            aq.Lot_Number__c         = wo.Lot_Number__c;
            aq.Scheduled_Date__c     = wo.Scheduled_Date__c;
            aq.ParentWorkOrderId     = wo.Id;
            aq.Aqua_Tech__c          = comm.Aqua_Tech__c;
            aq.FM__c                 = wo.FM__c;          // same crew FM
            aq.Subject               = TYPE_INSTALL + ' — ' + wo.Lot_Address__c
                + ' — ' + (wo.Scheduled_Date__c != null ? wo.Scheduled_Date__c.format() : 'TBD');
            aq.Description           = 'Aqua Install: install temporary irrigation components at lot. '
                + 'Record exact quantities installed: hoses, controllers, heads, valves. '
                + 'Confirm quantities when closing ticket — these become the on-site inventory record.';
            aquaTickets.add(aq);
        }

        if (!aquaTickets.isEmpty()) {
            LOVING_TriggerGuard.clearAlreadyRun('WorkOrder');
            insert aquaTickets;
        }
    }

    // ── Create Aqua Check Ticket ─────────────────────────────────────────────
    /**
     * Called when an Aqua Install Ticket closes with confirmed quantities.
     * Creates the first Check Ticket for the next community service day.
     * Subsequent check tickets are created by the nightly scheduled flow.
     */
    public static void createFirstCheckTicket(WorkOrder aquaInstallWO) {
        Account community = [
            SELECT Id, Aqua_Tech__c, Aqua_Service_Days__c
            FROM Account
            WHERE Id = :aquaInstallWO.Community__c
            LIMIT 1
        ];

        Date nextServiceDay = getNextServiceDay(community.Aqua_Service_Days__c, Date.today().addDays(1));

        WorkOrder check            = new WorkOrder();
        check.Work_Order_Type__c   = TYPE_CHECK;
        check.Status               = 'New';
        check.AccountId            = aquaInstallWO.AccountId;
        check.Community__c         = aquaInstallWO.Community__c;
        check.Builder_Regional__c  = aquaInstallWO.Builder_Regional__c;
        check.Lot__c               = aquaInstallWO.Lot__c;
        check.Lot_Address__c       = aquaInstallWO.Lot_Address__c;
        check.Lot_Number__c        = aquaInstallWO.Lot_Number__c;
        check.Scheduled_Date__c    = nextServiceDay;
        check.ParentWorkOrderId    = aquaInstallWO.Id;
        check.Aqua_Tech__c         = community.Aqua_Tech__c;
        // Copy installed quantities as expected quantities
        check.Expected_Hoses__c        = aquaInstallWO.Confirmed_Hoses__c;
        check.Expected_Controllers__c  = aquaInstallWO.Confirmed_Controllers__c;
        check.Expected_Heads__c        = aquaInstallWO.Confirmed_Heads__c;
        check.Expected_Valves__c       = aquaInstallWO.Confirmed_Valves__c;
        check.Check_Visit_Number__c    = 1;
        check.Is_First_Visit__c        = true;
        check.Subject = TYPE_CHECK + ' #1 — ' + aquaInstallWO.Lot_Address__c
            + ' — ' + nextServiceDay.format();

        insert check;
    }

    // ── Create Aqua Pickup Ticket ────────────────────────────────────────────
    /**
     * Called when a lot is marked Closed (Lot_Status__c = Closed).
     * Schedules pickup on next community service day.
     */
    public static void createPickupTicket(Id lotAccountId) {
        Account lot = [
            SELECT Id, ParentId, Lot_Number__c, Street_Address__c,
                   (SELECT Id FROM WorkOrders WHERE Work_Order_Type__c = 'Aqua Install'
                    AND Status = 'Completed' ORDER BY CreatedDate DESC LIMIT 1)
            FROM Account WHERE Id = :lotAccountId LIMIT 1
        ];

        Account community = [
            SELECT Id, Aqua_Tech__c, Aqua_Service_Days__c
            FROM Account WHERE Id = :lot.ParentId LIMIT 1
        ];

        Date nextPickupDay = getNextServiceDay(community.Aqua_Service_Days__c, Date.today());

        WorkOrder pickup           = new WorkOrder();
        pickup.Work_Order_Type__c  = TYPE_PICKUP;
        pickup.Status              = 'New';
        pickup.AccountId           = lotAccountId;
        pickup.Community__c        = community.Id;
        pickup.Lot__c              = lotAccountId;
        pickup.Lot_Address__c      = lot.Street_Address__c;
        pickup.Lot_Number__c       = lot.Lot_Number__c;
        pickup.Scheduled_Date__c   = nextPickupDay;
        pickup.Aqua_Tech__c        = community.Aqua_Tech__c;
        pickup.Subject = TYPE_PICKUP + ' — ' + lot.Street_Address__c
            + ' — ' + nextPickupDay.format();
        pickup.Description = 'Final pickup. Retrieve ALL Aqua equipment from lot. '
            + 'Enter actual quantities retrieved. Any variance vs expected triggers '
            + 'inventory reconciliation and billing adjustment.';

        insert pickup;

        // Cancel all future open check tickets for this lot
        List<WorkOrder> futureChecks = [
            SELECT Id FROM WorkOrder
            WHERE Work_Order_Type__c = :TYPE_CHECK
            AND AccountId = :lotAccountId
            AND Status NOT IN ('Completed', 'Cancelled')
        ];
        for (WorkOrder fc : futureChecks) {
            fc.Status = 'Cancelled';
        }
        if (!futureChecks.isEmpty()) update futureChecks;
    }

    // ── Utility: Next Service Day ─────────────────────────────────────────────
    /**
     * Given a multi-select picklist of service days and a start date,
     * returns the next qualifying date.
     * Service day values: Monday, Tuesday, Wednesday, Thursday, Friday
     */
    public static Date getNextServiceDay(String serviceDaysMSL, Date startDate) {
        if (String.isBlank(serviceDaysMSL)) {
            return startDate; // default to start date if not configured
        }

        Set<String> serviceDays = new Set<String>(serviceDaysMSL.split(';'));
        Date candidate = startDate;

        for (Integer i = 0; i < 14; i++) { // max 2-week lookahead
            String dayName = getDayName(candidate.toStartOfWeek().daysBetween(candidate));
            if (serviceDays.contains(dayName)) {
                return candidate;
            }
            candidate = candidate.addDays(1);
        }
        return startDate; // fallback
    }

    private static String getDayName(Integer dayOfWeekOffset) {
        // Salesforce week starts Sunday (0)
        Map<Integer, String> dayMap = new Map<Integer, String>{
            0 => 'Sunday', 1 => 'Monday', 2 => 'Tuesday',
            3 => 'Wednesday', 4 => 'Thursday', 5 => 'Friday', 6 => 'Saturday'
        };
        return dayMap.get(dayOfWeekOffset);
    }
}
