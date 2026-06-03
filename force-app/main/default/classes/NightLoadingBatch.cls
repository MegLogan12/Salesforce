public class NightLoadingBatch implements Database.Batchable<SObject>, Schedulable {

    // One Loading_Ticket__c per WorkOrder scheduled for loadDate.
    // External_Key__c (upsert key) = WO_Id + '-' + loadDate, ensuring idempotency:
    //   re-running regenerates lines but never duplicates the ticket header.
    // Loaded__c flags on existing lines are preserved across re-runs by product.
    // A truck releases only when every line's Loaded__c = true (enforcement via
    // Loading_Ticket__c.Release_Requires_All_Loaded validation rule).

    private final Date loadDate;

    public NightLoadingBatch()       { this.loadDate = Date.today().addDays(1); }
    public NightLoadingBatch(Date d) { this.loadDate = d; }

    public static void run() {
        Database.executeBatch(new NightLoadingBatch(), 200);
    }

    public void execute(SchedulableContext sc) {
        Database.executeBatch(new NightLoadingBatch(), 200);
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator(
            'SELECT Id, Crew__c FROM WorkOrder ' +
            'WHERE StartDate = :loadDate ' +
            '  AND Status NOT IN (\'Cancelled\', \'Closed\', \'Completed\',' +
            '                     \'Invoiced\', \'Paid\', \'Closeout Approved\')'
        );
    }

    public void execute(Database.BatchableContext bc, List<WorkOrder> scope) {
        if (scope.isEmpty()) return;
        processScope(scope, loadDate);
    }

    @TestVisible
    static void processScope(List<WorkOrder> scope, Date ld) {
        Set<Id> woIds = (new Map<Id, WorkOrder>(scope)).keySet();

        // Upsert one Loading_Ticket__c per WO (idempotent via External_Key__c)
        List<Loading_Ticket__c> tickets = new List<Loading_Ticket__c>();
        List<Id>                woOrder = new List<Id>(woIds);
        for (WorkOrder wo : scope) {
            tickets.add(new Loading_Ticket__c(
                External_Key__c = wo.Id + '-' + String.valueOf(ld),
                Work_Order__c   = wo.Id,
                Crew__c         = wo.Crew__c,
                Load_Date__c    = ld,
                Status__c       = 'Not Submitted'
            ));
        }
        Database.UpsertResult[] ticketResults =
            Database.upsert(tickets, Loading_Ticket__c.External_Key__c, false);

        // Build WO → ticket Id map from successful upserts
        Map<Id, Id> ticketIdByWoId = new Map<Id, Id>();
        Integer i = 0;
        for (WorkOrder wo : scope) {
            if (ticketResults[i].isSuccess()) {
                ticketIdByWoId.put(wo.Id, ticketResults[i].getId());
            }
            i++;
        }
        if (ticketIdByWoId.isEmpty()) return;

        Set<Id> ticketIds = new Set<Id>(ticketIdByWoId.values());

        // Snapshot existing Loaded__c flags per product so re-runs preserve crew progress
        Map<Id, Map<Id, Boolean>> loadedByProductByTicket = new Map<Id, Map<Id, Boolean>>();
        for (Loading_Ticket_Line__c existing : [
            SELECT Loading_Ticket__c, Product__c, Loaded__c
            FROM Loading_Ticket_Line__c
            WHERE Loading_Ticket__c IN :ticketIds
        ]) {
            if (!loadedByProductByTicket.containsKey(existing.Loading_Ticket__c)) {
                loadedByProductByTicket.put(existing.Loading_Ticket__c, new Map<Id, Boolean>());
            }
            loadedByProductByTicket.get(existing.Loading_Ticket__c)
                .put(existing.Product__c, existing.Loaded__c);
        }

        // Delete existing lines so the current material list is always authoritative
        List<Loading_Ticket_Line__c> toDelete = [
            SELECT Id FROM Loading_Ticket_Line__c WHERE Loading_Ticket__c IN :ticketIds
        ];
        if (!toDelete.isEmpty()) delete toDelete;

        // Build lines from WorkOrderLineItems; preserve Loaded__c where product was
        // already loaded by crew before this re-run
        List<Loading_Ticket_Line__c> newLines = new List<Loading_Ticket_Line__c>();
        for (WorkOrderLineItem woli : [
            SELECT WorkOrderId, Product2Id, Quantity
            FROM WorkOrderLineItem
            WHERE WorkOrderId IN :woIds
              AND Product2Id != null
        ]) {
            Id ticketId = ticketIdByWoId.get(woli.WorkOrderId);
            if (ticketId == null) continue;
            Map<Id, Boolean> loadedByProd = loadedByProductByTicket.containsKey(ticketId)
                                            ? loadedByProductByTicket.get(ticketId)
                                            : new Map<Id, Boolean>();
            newLines.add(new Loading_Ticket_Line__c(
                Loading_Ticket__c    = ticketId,
                Product__c           = woli.Product2Id,
                Quantity__c          = woli.Quantity != null ? woli.Quantity : 1,
                Source_Work_Order__c = woli.WorkOrderId,
                Loaded__c            = loadedByProd.containsKey(woli.Product2Id)
                                       ? loadedByProd.get(woli.Product2Id) : false
            ));
        }
        if (!newLines.isEmpty()) insert newLines;
    }

    public void finish(Database.BatchableContext bc) {}
}
