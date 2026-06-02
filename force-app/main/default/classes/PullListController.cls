public with sharing class PullListController {

    public class PullTicketDTO {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String status;
        @AuraEnabled public Id workOrderId;
        @AuraEnabled public String workOrderSubject;
        @AuraEnabled public Id itemCatalogId;
        @AuraEnabled public String itemName;
        @AuraEnabled public String itemNumber;
        @AuraEnabled public String storageLocation;
        @AuraEnabled public Decimal quantityRequested;
        @AuraEnabled public Decimal quantityPulled;
        @AuraEnabled public Id pulledById;
        @AuraEnabled public String pulledByName;
        @AuraEnabled public Date pulledDate;
        @AuraEnabled public Date scheduledDate;
    }

    public class ActionResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
        public ActionResult(Boolean success, String message) {
            this.success = success;
            this.message = message;
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<PullTicketDTO> getPullList(Date schedDate) {
        if (schedDate == null) schedDate = Date.today();

        List<Pull_Ticket__c> tickets = [
            SELECT Id, Name, Status__c,
                   Work_Order__c, Work_Order__r.Subject, Work_Order__r.Schedule_Locked__c,
                   Item_Catalog__c, Item_Catalog__r.Name, Item_Catalog__r.Item_Number__c,
                   Item_Catalog__r.Storage_Location__c,
                   Quantity_Requested__c, Quantity_Pulled__c,
                   Pulled_By__c, Pulled_By__r.Name, Pulled_Date__c,
                   Scheduled_Date__c
            FROM Pull_Ticket__c
            WHERE Scheduled_Date__c = :schedDate
              AND Work_Order__r.Schedule_Locked__c = true
              AND Status__c = 'Pending Pull'
            ORDER BY Name
        ];

        List<PullTicketDTO> result = new List<PullTicketDTO>();
        for (Pull_Ticket__c t : tickets) {
            PullTicketDTO dto = new PullTicketDTO();
            dto.id                = t.Id;
            dto.name              = t.Name;
            dto.status            = t.Status__c;
            dto.workOrderId       = t.Work_Order__c;
            dto.workOrderSubject  = t.Work_Order__r != null ? t.Work_Order__r.Subject : null;
            dto.itemCatalogId     = t.Item_Catalog__c;
            dto.itemName          = t.Item_Catalog__r != null ? t.Item_Catalog__r.Name : null;
            dto.itemNumber        = t.Item_Catalog__r != null ? t.Item_Catalog__r.Item_Number__c : null;
            dto.storageLocation   = t.Item_Catalog__r != null ? t.Item_Catalog__r.Storage_Location__c : null;
            dto.quantityRequested = t.Quantity_Requested__c;
            dto.quantityPulled    = t.Quantity_Pulled__c;
            dto.pulledById        = t.Pulled_By__c;
            dto.pulledByName      = t.Pulled_By__r != null ? t.Pulled_By__r.Name : null;
            dto.pulledDate        = t.Pulled_Date__c;
            dto.scheduledDate     = t.Scheduled_Date__c;
            result.add(dto);
        }
        return result;
    }

    @AuraEnabled
    public static ActionResult confirmPull(Id pullTicketId, Decimal qtyPulled, Id pulledByUserId) {
        if (pullTicketId == null) {
            return new ActionResult(false, 'Pull ticket ID is required.');
        }
        if (qtyPulled == null || qtyPulled <= 0) {
            return new ActionResult(false, 'Quantity pulled must be greater than zero.');
        }
        if (pulledByUserId == null) {
            return new ActionResult(false, 'Responsible user is required to confirm a pull.');
        }

        Pull_Ticket__c ticket;
        try {
            ticket = [
                SELECT Id, Status__c, Item_Catalog__c,
                       Item_Catalog__r.Storage_Location__c, Item_Catalog__r.Quantity_On_Hand__c,
                       Work_Order__c, Work_Order__r.Schedule_Locked__c
                FROM Pull_Ticket__c
                WHERE Id = :pullTicketId
                LIMIT 1
            ];
        } catch (QueryException e) {
            return new ActionResult(false, 'Pull ticket not found.');
        }

        if (ticket.Status__c == 'Pulled') {
            return new ActionResult(false, 'This pull ticket has already been confirmed.');
        }
        if (ticket.Status__c == 'Cancelled') {
            return new ActionResult(false, 'Cannot confirm a cancelled pull ticket.');
        }
        if (ticket.Item_Catalog__c == null) {
            return new ActionResult(false, 'Cannot confirm pull: no item catalog entry linked. Set Item Catalog before confirming.');
        }
        if (String.isBlank(ticket.Item_Catalog__r.Storage_Location__c)) {
            return new ActionResult(false, 'Cannot confirm pull: item has no storage location. Update the Item Catalog record before pulling.');
        }
        if (ticket.Work_Order__r == null || ticket.Work_Order__r.Schedule_Locked__c != true) {
            return new ActionResult(false, 'Cannot confirm pull: the linked work order is not scheduled (Schedule Locked must be true).');
        }

        Savepoint sp = Database.setSavepoint();
        try {
            update new Pull_Ticket__c(
                Id             = ticket.Id,
                Status__c      = 'Pulled',
                Quantity_Pulled__c = qtyPulled,
                Pulled_By__c   = pulledByUserId,
                Pulled_Date__c = Date.today()
            );

            Decimal current = ticket.Item_Catalog__r.Quantity_On_Hand__c != null
                ? ticket.Item_Catalog__r.Quantity_On_Hand__c : 0;
            update new Item_Catalog__c(
                Id                  = ticket.Item_Catalog__c,
                Quantity_On_Hand__c = current - qtyPulled
            );

        } catch (Exception e) {
            Database.rollback(sp);
            return new ActionResult(false, 'Pull confirmation failed: ' + e.getMessage());
        }

        return new ActionResult(true, 'Pull confirmed. Item catalog quantity decremented.');
    }
}