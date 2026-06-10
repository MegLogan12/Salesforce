trigger LeadTrigger on Lead (before insert, before update, after insert, after update) {
    if (Trigger.isBefore) {
        LeadHandler.handleBefore(Trigger.new, Trigger.oldMap);
    }
    if (Trigger.isAfter) {
        LeadHandler.handleAfter(Trigger.new, Trigger.oldMap);
    }
}