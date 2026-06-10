trigger OpportunityNoteNotificationTrigger on ContentDocumentLink (after insert) {
    OpportunityNoteNotificationHandler.handleAfterInsert(Trigger.new);
}