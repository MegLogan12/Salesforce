public with sharing class NightLoadingQueueController {

    public class TicketRow {
        @AuraEnabled public Id ticketId;
        @AuraEnabled public String ticketName;
        @AuraEnabled public Decimal truckNumber;
        @AuraEnabled public String status;
        @AuraEnabled public Date loadDate;
        @AuraEnabled public Integer totalLines;
        @AuraEnabled public Integer loadedLines;
        @AuraEnabled public List<LineRow> lines;
    }

    public class LineRow {
        @AuraEnabled public Id lineId;
        @AuraEnabled public String productName;
        @AuraEnabled public Decimal quantity;
        @AuraEnabled public Boolean loaded;
        @AuraEnabled public Id sourceWorkOrderId;
        @AuraEnabled public String notes;
    }

    @AuraEnabled(cacheable=true)
    public static List<TicketRow> getQueue(Date loadDate) {
        Date d = loadDate != null ? loadDate : Date.today();
        Map<Id, TicketRow> ticketMap = new Map<Id, TicketRow>();

        for (Loading_Ticket__c lt : [
            SELECT Id, Name, Truck_Number__c, Status__c, Load_Date__c
            FROM Loading_Ticket__c
            WHERE Load_Date__c = :d
            ORDER BY Truck_Number__c NULLS LAST
        ]) {
            TicketRow tr = new TicketRow();
            tr.ticketId    = lt.Id;
            tr.ticketName  = lt.Name;
            tr.truckNumber = lt.Truck_Number__c;
            tr.status      = lt.Status__c;
            tr.loadDate    = lt.Load_Date__c;
            tr.totalLines  = 0;
            tr.loadedLines = 0;
            tr.lines       = new List<LineRow>();
            ticketMap.put(lt.Id, tr);
        }

        for (Loading_Ticket_Line__c ltl : [
            SELECT Id, Loading_Ticket__c, Product__r.Name, Quantity__c, Loaded__c,
                   Source_Work_Order__c, Notes__c
            FROM Loading_Ticket_Line__c
            WHERE Loading_Ticket__c IN :ticketMap.keySet()
            ORDER BY Loading_Ticket__c, Product__r.Name
        ]) {
            TicketRow tr = ticketMap.get(ltl.Loading_Ticket__c);
            LineRow lr = new LineRow();
            lr.lineId            = ltl.Id;
            lr.productName       = ltl.Product__r != null ? ltl.Product__r.Name : 'Unknown';
            lr.quantity          = ltl.Quantity__c;
            lr.loaded            = ltl.Loaded__c;
            lr.sourceWorkOrderId = ltl.Source_Work_Order__c;
            lr.notes             = ltl.Notes__c;
            tr.lines.add(lr);
            tr.totalLines++;
            if (ltl.Loaded__c) tr.loadedLines++;
        }

        return ticketMap.values();
    }

    @AuraEnabled
    public static void markLoaded(Id lineId, Boolean loaded) {
        Loading_Ticket_Line__c ltl = [
            SELECT Id, Loading_Ticket__c, Loaded__c FROM Loading_Ticket_Line__c WHERE Id = :lineId LIMIT 1
        ];
        ltl.Loaded__c = loaded;
        update ltl;

        Loading_Ticket__c lt = [SELECT Id, Status__c FROM Loading_Ticket__c WHERE Id = :ltl.Loading_Ticket__c LIMIT 1];
        if (lt.Status__c == 'Generated' || lt.Status__c == 'Not Submitted') {
            lt.Status__c = 'Loading';
            update lt;
        }
    }

    @AuraEnabled
    public static void releaseTruck(Id ticketId) {
        List<Loading_Ticket_Line__c> lines = [
            SELECT Id, Loaded__c FROM Loading_Ticket_Line__c WHERE Loading_Ticket__c = :ticketId
        ];
        if (lines.isEmpty()) {
            throw new AuraHandledException('No lines on this ticket — cannot release.');
        }
        for (Loading_Ticket_Line__c l : lines) {
            if (!l.Loaded__c) {
                throw new AuraHandledException('All lines must be loaded before releasing the truck.');
            }
        }
        update new Loading_Ticket__c(Id = ticketId, Status__c = 'Released');
    }

    @AuraEnabled
    public static void regenerate(Date loadDate) {
        NightLoadingGenerateSchedulable.generate(loadDate != null ? loadDate : Date.today());
    }
}