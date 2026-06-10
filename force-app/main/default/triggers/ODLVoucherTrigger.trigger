trigger ODLVoucherTrigger on Voucher__c (before insert, before update, after insert, after update) {
    if (Trigger.isBefore) {
        if (Trigger.isInsert) {
            ODLVoucherCodeService.assignMissingCodes(Trigger.new);
        }
        ODLVoucherLifecycleService.handleVoucherBefore(Trigger.new, Trigger.isInsert ? null : Trigger.oldMap);
    }
    if (Trigger.isAfter) {
        ODLVoucherLifecycleService.handleVoucherAfter(Trigger.new);
    }
}