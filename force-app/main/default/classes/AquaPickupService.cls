/**
 * AquaPickupService
 * Handles bulk end-of-season retrieval, pickup reassignment, and variance billing triggers.
 * Called from AquaConsoleController @AuraEnabled wrapper methods.
 */
public without sharing class AquaPickupService {

    // Season boundaries (April 1 – October 31)
    private static final Integer SEASON_END_MONTH = 10;
    private static final Integer SEASON_END_DAY   = 31;

    // Allows unit tests to bypass the season-end gate without needing override permission
    @TestVisible private static Boolean skipSeasonGateForTest = false;

    /**
     * Bulk-create Aqua_Pickup_Ticket__c for every Lot__c where Aqua_Installed__c = true
     * and there is no existing pending pickup ticket.
     * Requires LOVING_Aqua_Override permission OR today >= season end date.
     */
    public static void bulkRetrieve() {
        Date seasonEnd = Date.newInstance(Date.today().year(), SEASON_END_MONTH, SEASON_END_DAY);
        Boolean hasOverride = FeatureManagement.checkPermission('LOVING_Aqua_Override');
        if (!hasOverride && Date.today() < seasonEnd && !skipSeasonGateForTest) {
            throw new AuraHandledException(
                'End-of-season bulk retrieve is disabled until ' + seasonEnd.format()
                + '. Request override permission from your manager.'
            );
        }

        List<Lot__c> activeLots = [
            SELECT Id, Name, Community__c
            FROM Lot__c
            WHERE Aqua_Installed__c = true
            AND Closing_Date__c = null
        ];
        if (activeLots.isEmpty()) return;

        Set<Id> lotIds = new Set<Id>();
        for (Lot__c l : activeLots) lotIds.add(l.Id);

        Set<Id> alreadyQueued = new Set<Id>();
        for (Aqua_Pickup_Ticket__c pt : [
            SELECT Lot__c
            FROM Aqua_Pickup_Ticket__c
            WHERE Status__c != 'Closed'
            AND Lot__c IN :lotIds
        ]) {
            alreadyQueued.add(pt.Lot__c);
        }

        List<Aqua_Pickup_Ticket__c> toInsert = new List<Aqua_Pickup_Ticket__c>();
        for (Lot__c l : activeLots) {
            if (alreadyQueued.contains(l.Id)) continue;
            Aqua_Pickup_Ticket__c pt = new Aqua_Pickup_Ticket__c(
                Lot__c            = l.Id,
                Aqua_Community__c = l.Community__c,  // Community__c custom object via Lot
                Status__c         = 'Open',
                Scheduled_Date__c = Date.today()
            );
            toInsert.add(pt);
        }

        if (toInsert.isEmpty()) return;
        insert toInsert;

        Task audit = new Task(
            Subject     = 'Aqua End-of-Season Bulk Retrieve',
            Description = 'Bulk retrieve initiated for ' + toInsert.size() + ' active lot(s) by '
                          + UserInfo.getName() + ' on ' + System.now().format(),
            Status      = 'Completed',
            Priority    = 'Normal'
        );
        insert audit;
    }

    /**
     * Reassign a pickup ticket to a different tech (User Id — Assigned_To__c is a User lookup).
     */
    public static void reassignPickup(Id pickupTicketId, Id newUserId) {
        if (pickupTicketId == null || newUserId == null) {
            throw new AuraHandledException('Pickup ticket and tech are required.');
        }
        Aqua_Pickup_Ticket__c pt = [
            SELECT Id, Assigned_To__c
            FROM Aqua_Pickup_Ticket__c
            WHERE Id = :pickupTicketId
            LIMIT 1
        ];
        pt.Assigned_To__c = newUserId;
        update pt;
    }

    /**
     * Complete pickup reconciliation: set Device_Retrieved__c and Inventory_Reconciled__c.
     * If variance fields populated, triggers billing task.
     */
    public static void completeReconciliation(Id pickupTicketId, Boolean deviceRetrieved,
                                              Integer varianceControllers, Integer varianceHeads) {
        if (pickupTicketId == null) throw new AuraHandledException('Pickup ticket ID is required.');
        Aqua_Pickup_Ticket__c pt = [
            SELECT Id, Status__c, Lot__c, Aqua_Community__c,
                   Device_Retrieved__c, Inventory_Reconciled__c,
                   Variance_Controllers__c, Variance_Heads__c
            FROM Aqua_Pickup_Ticket__c
            WHERE Id = :pickupTicketId
            LIMIT 1
        ];
        if (!deviceRetrieved) {
            throw new AuraHandledException('Device must be marked as retrieved before completing reconciliation.');
        }
        pt.Device_Retrieved__c     = true;
        pt.Inventory_Reconciled__c = true;
        pt.Variance_Controllers__c = varianceControllers != null ? varianceControllers : 0;
        pt.Variance_Heads__c       = varianceHeads != null ? varianceHeads : 0;
        pt.Status__c               = 'Closed';
        pt.Closed_Date__c          = Date.today();
        update pt;

        Boolean hasVariance = (varianceControllers != null && varianceControllers > 0)
                           || (varianceHeads != null && varianceHeads > 0);
        if (hasVariance) {
            triggerVarianceBilling(pt);
        }
    }

    private static void triggerVarianceBilling(Aqua_Pickup_Ticket__c pt) {
        String cmName = '';
        if (pt.Aqua_Community__c != null) {
            List<Community__c> comms = [
                SELECT CM_Contact__r.Name FROM Community__c
                WHERE Id = :pt.Aqua_Community__c LIMIT 1
            ];
            if (!comms.isEmpty() && comms[0].CM_Contact__r != null) {
                cmName = comms[0].CM_Contact__r.Name;
            }
        }

        Decimal bill = calculateBillAmount(pt);

        Task billingTask = new Task(
            Subject     = 'Aqua Pickup Variance — Billing Required',
            Description = 'Variance detected on pickup ticket ' + pt.Id
                          + '. Controllers missing: ' + (pt.Variance_Controllers__c != null ? pt.Variance_Controllers__c : 0)
                          + '. Heads missing: ' + (pt.Variance_Heads__c != null ? pt.Variance_Heads__c : 0)
                          + '. CM: ' + cmName
                          + '. Estimated bill: $' + bill.setScale(2),
            Status      = 'Not Started',
            Priority    = 'High'
        );
        insert billingTask;
    }

    private static Decimal calculateBillAmount(Aqua_Pickup_Ticket__c pt) {
        Map<String, Decimal> unitCosts = new Map<String, Decimal>();
        for (Aqua_Master_Inventory__c item : [
            SELECT Item_Type__c, Unit_Cost__c
            FROM Aqua_Master_Inventory__c
            WHERE Unit_Cost__c != null
        ]) {
            unitCosts.put(item.Item_Type__c, item.Unit_Cost__c);
        }
        Decimal total = 0;
        if (pt.Variance_Controllers__c != null && pt.Variance_Controllers__c > 0) {
            Decimal cost = unitCosts.containsKey('Controllers') ? unitCosts.get('Controllers') : 0;
            total += pt.Variance_Controllers__c * cost;
        }
        if (pt.Variance_Heads__c != null && pt.Variance_Heads__c > 0) {
            Decimal cost = unitCosts.containsKey('Heads') ? unitCosts.get('Heads') : 0;
            total += pt.Variance_Heads__c * cost;
        }
        return total;
    }
}