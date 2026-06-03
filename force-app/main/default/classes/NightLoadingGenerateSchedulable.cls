public without sharing class NightLoadingGenerateSchedulable implements Schedulable {

    @TestVisible
    private static List<WorkOrder> testWorkOrders;

    public void execute(SchedulableContext ctx) {
        generate(Date.today().addDays(1));
    }

    public static void generate(Date targetDate) {
        List<WorkOrder> wos;
        if (Test.isRunningTest() && testWorkOrders != null) {
            wos = testWorkOrders;
        } else {
            wos = [
                SELECT Id, Subject, (
                    SELECT Id, Product2Id, Product2.Name, Quantity
                    FROM WorkOrderLineItems
                    WHERE Is_Inventory_Item__c = true
                )
                FROM WorkOrder
                WHERE Scheduled_Date__c = :targetDate
                  AND Status != 'Closed'
                  AND Status != 'Cancelled'
            ];
        }

        if (wos.isEmpty()) return;

        Set<Id> woIds = new Set<Id>();
        for (WorkOrder wo : wos) {
            if (wo.Id != null) woIds.add(wo.Id);
        }

        Map<Id, Loading_Ticket__c> existingById = new Map<Id, Loading_Ticket__c>();
        for (Loading_Ticket__c lt : [
            SELECT Id, Name, Status__c, Scheduled_Date__c
            FROM Loading_Ticket__c
            WHERE Load_Date__c = :targetDate
        ]) {
            existingById.put(lt.Id, lt);
        }

        Set<Id> existingTicketIds = existingById.keySet();
        Map<Id, Id> woToExistingTicket = new Map<Id, Id>();
        if (!existingTicketIds.isEmpty() && !woIds.isEmpty()) {
            for (Loading_Ticket_Line__c ltl : [
                SELECT Loading_Ticket__c, Source_Work_Order__c
                FROM Loading_Ticket_Line__c
                WHERE Loading_Ticket__c IN :existingTicketIds
                  AND Source_Work_Order__c IN :woIds
            ]) {
                woToExistingTicket.put(ltl.Source_Work_Order__c, ltl.Loading_Ticket__c);
            }
        }

        List<Loading_Ticket__c> toInsert = new List<Loading_Ticket__c>();
        List<Loading_Ticket__c> toUpdate = new List<Loading_Ticket__c>();
        Map<Id, Id> woToTicketId = new Map<Id, Id>(woToExistingTicket);

        for (WorkOrder wo : wos) {
            if (wo.Id == null) continue;
            if (woToExistingTicket.containsKey(wo.Id)) {
                Loading_Ticket__c lt = existingById.get(woToExistingTicket.get(wo.Id));
                if (lt != null && lt.Status__c != 'Released') {
                    toUpdate.add(new Loading_Ticket__c(
                        Id           = lt.Id,
                        Status__c    = 'Generated',
                        Load_Date__c = targetDate
                    ));
                }
            } else {
                Loading_Ticket__c newTicket = new Loading_Ticket__c(
                    Status__c         = 'Generated',
                    Load_Date__c      = targetDate,
                    Scheduled_Date__c = targetDate
                );
                toInsert.add(newTicket);
                woToTicketId.put(wo.Id, wo.Id);
            }
        }

        if (!toInsert.isEmpty()) {
            insert toInsert;
            Integer i = 0;
            for (WorkOrder wo : wos) {
                if (wo.Id == null) continue;
                if (!woToExistingTicket.containsKey(wo.Id) && i < toInsert.size()) {
                    woToTicketId.put(wo.Id, toInsert[i].Id);
                    i++;
                }
            }
        }
        if (!toUpdate.isEmpty()) update toUpdate;

        Set<Id> refreshTicketIds = new Set<Id>(woToTicketId.values());
        if (!refreshTicketIds.isEmpty() && !woIds.isEmpty()) {
            delete [SELECT Id FROM Loading_Ticket_Line__c WHERE Loading_Ticket__c IN :refreshTicketIds AND Source_Work_Order__c IN :woIds];
        }

        List<Loading_Ticket_Line__c> newLines = new List<Loading_Ticket_Line__c>();
        for (WorkOrder wo : wos) {
            if (wo.Id == null) continue;
            Id ticketId = woToTicketId.get(wo.Id);
            if (ticketId == null) continue;
            List<WorkOrderLineItem> wolis = wo.WorkOrderLineItems;
            if (wolis == null) continue;
            for (WorkOrderLineItem woli : wolis) {
                if (woli.Product2Id == null) continue;
                newLines.add(new Loading_Ticket_Line__c(
                    Loading_Ticket__c    = ticketId,
                    Product__c           = woli.Product2Id,
                    Quantity__c          = woli.Quantity != null ? woli.Quantity : 1,
                    Loaded__c            = false,
                    Source_Work_Order__c = wo.Id
                ));
            }
        }
        if (!newLines.isEmpty()) insert newLines;
    }
}
