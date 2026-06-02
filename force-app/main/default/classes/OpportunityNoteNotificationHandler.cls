public without sharing class OpportunityNoteNotificationHandler {
    @TestVisible
    private static Integer lastEmailsPrepared = 0;

    public static void handleAfterInsert(List<ContentDocumentLink> newLinks) {
        lastEmailsPrepared = 0;

        Set<Id> oppIds = new Set<Id>();
        Set<Id> docIds = new Set<Id>();

        for (ContentDocumentLink link : newLinks) {
            if (link.LinkedEntityId != null &&
                link.LinkedEntityId.getSObjectType() == Opportunity.SObjectType) {
                oppIds.add(link.LinkedEntityId);
                docIds.add(link.ContentDocumentId);
            }
        }

        if (oppIds.isEmpty() || docIds.isEmpty()) {
            return;
        }

        Map<Id, Opportunity> oppMap = new Map<Id, Opportunity>([
            SELECT Id, Name, OwnerId, Owner.Name, Owner.Email
            FROM Opportunity
            WHERE Id IN :oppIds
        ]);

        Map<Id, ContentDocument> docMap = new Map<Id, ContentDocument>([
            SELECT Id, Title, CreatedById, CreatedBy.Name, FileType
            FROM ContentDocument
            WHERE Id IN :docIds
        ]);

        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        Set<String> sentKeys = new Set<String>();

        for (ContentDocumentLink link : newLinks) {
            if (link.LinkedEntityId == null ||
                link.LinkedEntityId.getSObjectType() != Opportunity.SObjectType) {
                continue;
            }

            Opportunity opp = oppMap.get(link.LinkedEntityId);
            ContentDocument doc = docMap.get(link.ContentDocumentId);

            if (opp == null || doc == null) {
                continue;
            }

            // Only send for Enhanced Notes, not regular files
            if (doc.FileType != 'SNOTE') {
                continue;
            }

            // Don't notify if the owner created their own note
            if (doc.CreatedById == opp.OwnerId) {
                continue;
            }

            if (opp.OwnerId == null || String.isBlank(opp.Owner.Email)) {
                continue;
            }

            String dedupeKey = opp.Id + '-' + doc.Id;
            if (!sentKeys.add(dedupeKey)) {
                continue;
            }

            String creatorName = (doc.CreatedBy != null)
                ? doc.CreatedBy.Name
                : 'A user';

            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setTargetObjectId(opp.OwnerId);
            mail.setSaveAsActivity(false);
            mail.setSubject('New note added to Opportunity: ' + opp.Name);
            mail.setPlainTextBody(
                creatorName + ' added a new note to Opportunity "' + opp.Name + '".\n\n' +
                'Note title: ' + doc.Title + '\n' +
                'Opportunity link: ' + URL.getOrgDomainUrl().toExternalForm() + '/' + opp.Id
            );

            emails.add(mail);
        }

        lastEmailsPrepared = emails.size();

        if (!emails.isEmpty()) {
            Messaging.sendEmail(emails);
        }
    }
}