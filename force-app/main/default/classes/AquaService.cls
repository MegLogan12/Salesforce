/**
 * AquaService
 * Addendum — Aqua Service Parallel Workflow
 *
 * Data model:
 *   Builder Market Account → Community (Opportunity) → Work Order (= the Lot)
 *
 * Each Work Order represents one lot. Aqua tickets are linked to the Work Order directly.
 * There are no separate Lot Account records.
 *
 * Stages:
 *   1. Aqua Install Ticket  — auto-created when sod install is scheduled for Aqua community
 *   2. Install Ticket Closed — crew confirms complete; system creates first Check Ticket
 *   3. Aqua Check Ticket    — next community service day; 3 close questions answered every check
 *   4. Watering Schedule    — Week 1: 3x/day 30 min | Week 2: 3x/week 20 min | Week 3: 1x/day 20 min | Week 4+: per program
 *   5. Billing Trigger      — Damage or missing material found; reason code drives workflow
 *   6. Pickup Ticket        — Work Order closed; retrieve all Aqua equipment; reconcile inventory
 *
 * Inventory tracks across 3 locations — must always balance:
 *   Shop (309 Morningside Rd) + Van (Scott/Jimbo truck) + On-Site (per Work Order)
 */
public with sharing class AquaService {

    // ─────────────────────────────────────────────
    // 1. AUTO-CREATE AQUA INSTALL TICKET
    // Called from SchedulingService.onScheduleLocked when wo.Aqua_Community__c = true
    // ─────────────────────────────────────────────
    public static void createInstallTicket(Work_Order__c wo) {
        if (!wo.Aqua_Community__c) return;

        Aqua_Install_Ticket__c ticket = new Aqua_Install_Ticket__c(
            LOVING_Work_Order__c = wo.Id,
            Aqua_Community__c   = wo.Community__c,
            Scheduled_Date__c   = wo.Scheduled_Date__c,
            Crew__c             = wo.Crew__c,
            FM_Assignment__c    = wo.FM_Assignment__c,
            Status__c           = 'Open',
            Controller_Count__c = 1,
            Heads_Count__c      = wo.Aqua_Heads_Count__c,
            Aqua_Flags_Required__c     = wo.Aqua_Flags_Count__c,
            Measuring_Cups_Required__c = wo.Aqua_Measuring_Cups__c
        );
        insert ticket;

        // Deduct from Shop inventory when ticket opens (moves to Van/On-Site)
        AquaInventoryService.allocateInstallInventory(ticket);
    }

    // ─────────────────────────────────────────────
    // 2. CLOSE INSTALL TICKET — auto-creates first Check Ticket
    // ─────────────────────────────────────────────
    public static void closeInstallTicket(Id installTicketId, Decimal controllerCount,
                                          Decimal headsCount, String notes) {
        Aqua_Install_Ticket__c ticket = [
            SELECT Id, Aqua_Community__c, LOVING_Work_Order__c
            FROM Aqua_Install_Ticket__c WHERE Id = :installTicketId
        ];

        ticket.Status__c                     = 'Closed';
        ticket.Closed_Date__c                = Date.today();
        ticket.Installed_Controller_Count__c = controllerCount;
        ticket.Installed_Heads_Count__c      = headsCount;
        ticket.Close_Notes__c                = notes;
        update ticket;

        // Confirm inventory moved to On-Site (keyed by Work Order = the lot)
        AquaInventoryService.confirmOnSiteInventory(ticket.LOVING_Work_Order__c, controllerCount, headsCount);

        // Auto-create first Check Ticket for next service day
        createCheckTicket(ticket.LOVING_Work_Order__c, ticket.Aqua_Community__c, 1);
    }

    // ─────────────────────────────────────────────
    // 3. AQUA CHECK TICKET — 3 close questions every check
    // ─────────────────────────────────────────────
    public static void createCheckTicket(Id workOrderId, Id communityId, Integer checkNumber) {
        Date nextServiceDay = getNextAquaServiceDay(communityId);
        Date installDate = getInstallCloseDate(workOrderId);

        Aqua_Check_Ticket__c checkTicket = new Aqua_Check_Ticket__c(
            LOVING_Work_Order__c = workOrderId,
            Aqua_Community__c = communityId,
            Check_Number__c   = checkNumber,
            Scheduled_Date__c = nextServiceDay,
            Status__c         = 'Open',
            Assigned_To__c    = getAquaTech(communityId),  // Jimbo
            Watering_Instructions__c = AquaWateringScheduleResolver.resolveWithInstallDate(
                communityId, installDate, nextServiceDay
            )
        );
        insert checkTicket;
    }

    private static Date getInstallCloseDate(Id workOrderId) {
        if (workOrderId == null) return null;
        List<Aqua_Install_Ticket__c> installs = [
            SELECT Closed_Date__c FROM Aqua_Install_Ticket__c
            WHERE LOVING_Work_Order__c = :workOrderId
                AND Status__c = 'Closed'
                AND Closed_Date__c != null
            ORDER BY Closed_Date__c DESC LIMIT 1
        ];
        return installs.isEmpty() ? null : installs[0].Closed_Date__c;
    }

    /**
     * Answer the 3 close questions on an Aqua Check Ticket.
     *
     * Q1: System Tampered? (Yes/No)
     * Q2: Turf Condition (Score 1–10)
     * Q3: Landscape Condition (Score 1–10)
     */
    public static void closeCheckTicket(
        Id checkTicketId,
        Boolean systemTampered,
        Decimal turfScore,
        Decimal landscapeScore,
        String notes
    ) {
        Aqua_Check_Ticket__c ticket = [
            SELECT Id, Aqua_Community__c, LOVING_Work_Order__c, Check_Number__c, Assigned_To__c
            FROM Aqua_Check_Ticket__c WHERE Id = :checkTicketId
        ];

        ticket.Status__c               = 'Closed';
        ticket.Closed_Date__c          = Date.today();
        ticket.System_Tampered__c      = systemTampered;
        ticket.Turf_Condition_Score__c = turfScore;
        ticket.Landscape_Score__c      = landscapeScore;
        ticket.Check_Notes__c          = notes;
        update ticket;

        // Q1: Tampering detected → Scott review queue
        if (systemTampered) {
            EscalationService.alertAquaTamperingDetected(ticket.LOVING_Work_Order__c, checkTicketId);
        }

        // Q2: Turf score < 5 → alert Erica immediately + require photo
        if (turfScore < 5) {
            EscalationService.alertTurfConditionLow(ticket.LOVING_Work_Order__c, turfScore);
        }

        // Q3: Landscape score < 5 → alert FM immediately + require photo
        if (landscapeScore < 5) {
            EscalationService.alertLandscapeConditionLow(ticket.LOVING_Work_Order__c, landscapeScore);
        }

        // Create next check ticket unless the Work Order (lot) is closed
        Integer nextCheckNumber = (Integer)ticket.Check_Number__c + 1;
        if (!isWorkOrderClosed(ticket.LOVING_Work_Order__c)) {
            createCheckTicket(ticket.LOVING_Work_Order__c, ticket.Aqua_Community__c, nextCheckNumber);
        }
    }

    // ─────────────────────────────────────────────
    // 4. WATERING SCHEDULE
    // Week 1: 3x/day 30 min | Week 2: 3x/week 20 min
    // Week 3: 1x/day 20 min | Week 4+: per program
    // ─────────────────────────────────────────────
    public static String getWateringSchedule(Date installDate) {
        Integer daysSinceInstall = installDate.daysBetween(Date.today());
        if (daysSinceInstall <= 7)  return 'Week 1: 3x/day, 30 minutes each';
        if (daysSinceInstall <= 14) return 'Week 2: 3x/week, 20 minutes each';
        if (daysSinceInstall <= 21) return 'Week 3: 1x/day, 20 minutes each';
        return 'Week 4+: Per established program';
    }

    // ─────────────────────────────────────────────
    // 5. BILLING TRIGGER — Reason Codes
    // ─────────────────────────────────────────────

    /**
     * Reason Code 1: Missing Material (Stolen)
     *   → Inventory workflow fires (3-location reconciliation)
     *   → Billing workflow fires — invoice generated for replacement
     *
     * Reason Code 2: Damaged / Malfunctioning (Warranty)
     *   → Inventory workflow fires
     *   → NO billing generated — warranty replacement tracked
     *
     * Reason Code 3: Additional Coverage Needed
     *   → Inventory workflow fires
     *   → Billing workflow fires — invoice generated for expanded coverage
     */
    public static void triggerAquaBilling(Id workOrderId, String reasonCode, String notes) {
        if (!new Set<String>{'1', '2', '3'}.contains(reasonCode)) {
            throw new AquaException('Invalid reason code: ' + reasonCode + '. Valid codes: 1 (Stolen), 2 (Warranty), 3 (Additional Coverage).');
        }

        // Always: run inventory reconciliation
        AquaInventoryService.reconcileThreeLocations(workOrderId);

        // Billing logic by reason code
        if (reasonCode == '1') {
            InvoiceService.generateAquaReplacementInvoice(workOrderId, workOrderId, 'Missing Material — Stolen', notes);
        } else if (reasonCode == '2') {
            AquaInventoryService.createWarrantyReplacement(workOrderId, notes);
        } else if (reasonCode == '3') {
            InvoiceService.generateAquaReplacementInvoice(workOrderId, workOrderId, 'Additional Coverage', notes);
        }
    }

    // ─────────────────────────────────────────────
    // 6. PICKUP TICKET — Work Order Closed
    // ─────────────────────────────────────────────
    public static void createPickupTicket(Id workOrderId, Id communityId) {
        Aqua_Pickup_Ticket__c pickup = new Aqua_Pickup_Ticket__c(
            LOVING_Work_Order__c = workOrderId,
            Aqua_Community__c   = communityId,
            Status__c       = 'Open',
            Assigned_To__c  = getAquaOwner(),  // Scott
            Scheduled_Date__c = Date.today().addDays(3)
        );
        insert pickup;
    }

    public static void closePickupTicket(Id pickupTicketId, Decimal controllersRetrieved,
                                         Decimal headsRetrieved, String notes) {
        Aqua_Pickup_Ticket__c ticket = [
            SELECT Id, LOVING_Work_Order__c FROM Aqua_Pickup_Ticket__c WHERE Id = :pickupTicketId
        ];

        ticket.Status__c                = 'Closed';
        ticket.Closed_Date__c           = Date.today();
        ticket.Controllers_Retrieved__c = controllersRetrieved;
        ticket.Heads_Retrieved__c       = headsRetrieved;
        ticket.Pickup_Notes__c          = notes;
        update ticket;

        // Return inventory from On-Site back to Shop
        AquaInventoryService.returnInventoryToShop(ticket.LOVING_Work_Order__c, controllersRetrieved, headsRetrieved);

        // Final 3-location reconciliation
        AquaInventoryService.reconcileThreeLocations(ticket.LOVING_Work_Order__c);
    }

    // ─────────────────────────────────────────────
    // HELPERS
    // ─────────────────────────────────────────────
    private static Date getNextAquaServiceDay(Id communityId) {
        List<Community_Service_Schedule__c> schedule = [
            SELECT Next_Service_Date__c FROM Community_Service_Schedule__c
            WHERE Community__c = :communityId AND Next_Service_Date__c >= :Date.today()
            ORDER BY Next_Service_Date__c ASC LIMIT 1
        ];
        return schedule.isEmpty() ? Date.today().addDays(1) : schedule[0].Next_Service_Date__c;
    }

    private static Id getAquaTech(Id communityId) {
        List<User> jimbo = [SELECT Id FROM User WHERE Name = 'Jimbo' AND IsActive = true LIMIT 1];
        return jimbo.isEmpty() ? UserInfo.getUserId() : jimbo[0].Id;
    }

    private static Id getAquaOwner() {
        List<User> scott = [SELECT Id FROM User WHERE Name = 'Scott' AND IsActive = true LIMIT 1];
        return scott.isEmpty() ? UserInfo.getUserId() : scott[0].Id;
    }

    // A lot is closed when its Work Order status is Closed
    private static Boolean isWorkOrderClosed(Id workOrderId) {
        List<Work_Order__c> wos = [SELECT Id, Status__c FROM Work_Order__c WHERE Id = :workOrderId LIMIT 1];
        return !wos.isEmpty() && wos[0].Status__c == 'Closed';
    }

    public class AquaException extends Exception {}
}