/**
 * OneOnOnePrepController
 * Backend for the oneOnOnePrep LWC on LOVING_OneOnOne_Record_Page.
 * Returns the OneOnOne__c record and its related Action_Item__c children.
 */
public with sharing class OneOnOnePrepController {

    // ── DTOs ─────────────────────────────────────────────────────────────────

    public class PrepDTO {
        @AuraEnabled public String         id;
        @AuraEnabled public String         name;
        @AuraEnabled public String         meetingDateLabel;
        @AuraEnabled public String         status;
        @AuraEnabled public String         attendees;
        @AuraEnabled public String         notes;
        @AuraEnabled public String         actionItemsSummary;
        @AuraEnabled public String         ownerName;
        @AuraEnabled public String         createdDateLabel;
        @AuraEnabled public List<ActionItemRow> actionItems;
    }

    public class ActionItemRow {
        @AuraEnabled public String  id;
        @AuraEnabled public String  name;
        @AuraEnabled public String  status;
        @AuraEnabled public String  dueDateLabel;
        @AuraEnabled public Boolean isOverdue;
        @AuraEnabled public String  statusChip;
    }

    // ── Helper ────────────────────────────────────────────────────────────────

    private static String chipClass(String status) {
        if (status == null) return 'chip-neutral';
        String s = status.toLowerCase();
        if (s.contains('open') || s.contains('pending'))    return 'chip-orange';
        if (s.contains('complet') || s.contains('closed'))  return 'chip-green';
        if (s.contains('cancel'))                           return 'chip-neutral';
        return 'chip-blue';
    }

    // ── Main query ────────────────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static PrepDTO getPrepData(Id recordId) {
        try {
            PrepDTO dto = new PrepDTO();
            Date today = Date.today();

            // Fetch the parent OneOnOne__c record
            List<OneOnOne__c> records = [
                SELECT Id, Name, Meeting_Date__c, Status__c, Attendees__c,
                       Notes__c, Action_Items__c, OwnerId, Owner.Name, CreatedDate
                FROM OneOnOne__c
                WHERE Id = :recordId
                LIMIT 1
            ];

            if (records.isEmpty()) {
                dto.name = 'Record not found';
                dto.actionItems = new List<ActionItemRow>();
                return dto;
            }

            OneOnOne__c rec = records[0];
            dto.id               = rec.Id;
            dto.name             = rec.Name;
            dto.meetingDateLabel = rec.Meeting_Date__c != null
                ? rec.Meeting_Date__c.month() + '/' + rec.Meeting_Date__c.day() + '/' + rec.Meeting_Date__c.year()
                : '';
            dto.status           = rec.Status__c       != null ? rec.Status__c       : '';
            dto.attendees        = rec.Attendees__c    != null ? rec.Attendees__c    : '';
            dto.notes            = rec.Notes__c        != null ? rec.Notes__c        : '';
            dto.actionItemsSummary = rec.Action_Items__c != null ? rec.Action_Items__c : '';
            dto.ownerName        = rec.Owner           != null ? rec.Owner.Name      : '';
            dto.createdDateLabel = rec.CreatedDate      != null
                ? rec.CreatedDate.format('M/d/yyyy')
                : '';

            // Related action items
            List<ActionItemRow> aiRows = new List<ActionItemRow>();
            for (Action_Item__c ai : [
                SELECT Id, Name, Status__c, Due_Date__c
                FROM Action_Item__c
                WHERE OneOnOne__c = :recordId
                ORDER BY Due_Date__c ASC NULLS LAST
                LIMIT 20
            ]) {
                ActionItemRow r = new ActionItemRow();
                r.id           = ai.Id;
                r.name         = ai.Name;
                r.status       = ai.Status__c != null ? ai.Status__c : '';
                r.dueDateLabel = ai.Due_Date__c != null
                    ? ai.Due_Date__c.month() + '/' + ai.Due_Date__c.day() + '/' + ai.Due_Date__c.year()
                    : '';
                r.isOverdue    = (ai.Due_Date__c != null && ai.Due_Date__c < today);
                r.statusChip   = chipClass(ai.Status__c);
                aiRows.add(r);
            }
            dto.actionItems = aiRows;

            return dto;

        } catch (Exception e) {
            throw new AuraHandledException('Unable to load 1:1 prep data: ' + e.getMessage());
        }
    }
}
